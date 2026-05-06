#!/usr/bin/env bash
# Codigo para obtener mapa MTSAT
# Autor: Yessenia Garcia Rizo
Usage() {
cat <<USAGE
Usage:
  $(basename "$0") -p PD_MTSAT -t T1_IMG -b B1_MAP -a ACQP_PD -A ACQP_T1 [options]

Example:
  $(basename "$0") \
    -p sag_FLASH_PD_Mtsat.nii.gz \
    -t sag_FLASH_T1.nii.gz \
    -b prefixdreamDREAM_B1.nii.gz \
    -a acqpPD \
    -A acqpT1 \
    -g 0 \
    -m /Users/yessenia_rizo/Documents/MATLAB

Compulsory arguments:
  -p    Archivo 4D sag_FLASH_PD_Mtsat.nii.gz
  -t    Archivo T1 (ej. sag_FLASH_T1.nii.gz)
  -b    Archivo B1 map (ej. prefixdreamDREAM_B1.nii.gz)
  -a    Archivo acqp de la imagen PD_Mtsat
  -A    Archivo acqp de la imagen T1

Optional arguments:
  -g    Valor del filtro gaussiano [default: 0]
  -m    Carpeta que contiene nii2mtsat.m [opcional]
  -h    Mostrar esta ayuda

Pipeline:
  1) Separación de volúmenes MT
  2) Lectura de scaling
  3) Registro con FLIRT
  4) Reaplicación de scaling
  5) Extracción de TR y flip angle
  6) Denoising
  7) Llamada a MATLAB / nii2mtsat

Notes:
  - Requiere: mrconvert, mrinfo, flirt, DenoiseImage, matlab
  - Si usas -m, esa carpeta se añade al path de MATLAB antes de llamar a nii2mtsat
USAGE
exit 1
}

# === Colores ===
verde="\033[1;32m"
rojo="\033[1;31m"
amarillo="\033[1;33m"
azul="\033[1;34m"
reset="\033[0m"

# Defaults

gaussianFilter=0
matlab_dir=""


# Parse args

while getopts ":p:t:b:a:A:g:m:h" opt; do
  case "$opt" in
    p) pd_mtsat="$OPTARG" ;;
    t) t1_img="$OPTARG" ;;
    b) b1_map="$OPTARG" ;;
    a) acqp_pd="$OPTARG" ;;
    A) acqp_t1="$OPTARG" ;;
    g) gaussianFilter="$OPTARG" ;;
    m) matlab_dir="$OPTARG" ;;
    h) Usage ;;
    \?) echo -e "${rojo}Error: opción inválida -$OPTARG${reset}"; Usage ;;
    :) echo -e "${rojo}Error: la opción -$OPTARG requiere un argumento${reset}"; Usage ;;
  esac
done


# Validaciones de argumentos

[[ -z "$pd_mtsat" ]] && { echo -e "${rojo}Error: falta -p${reset}"; Usage; }
[[ -z "$t1_img"   ]] && { echo -e "${rojo}Error: falta -t${reset}"; Usage; }
[[ -z "$b1_map"   ]] && { echo -e "${rojo}Error: falta -b${reset}"; Usage; }
[[ -z "$acqp_pd"  ]] && { echo -e "${rojo}Error: falta -a${reset}"; Usage; }
[[ -z "$acqp_t1"  ]] && { echo -e "${rojo}Error: falta -A${reset}"; Usage; }

for f in "$pd_mtsat" "$t1_img" "$b1_map" "$acqp_pd" "$acqp_t1"; do
  if [[ ! -f "$f" ]]; then
    echo -e "${rojo}Error: no se encontró el archivo '$f'${reset}"
    exit 1
  fi
done

if ! [[ "$gaussianFilter" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo -e "${rojo}Error: -g debe ser un número válido${reset}"
  exit 1
fi

if [[ -n "$matlab_dir" && ! -d "$matlab_dir" ]]; then
  echo -e "${rojo}Error: la carpeta MATLAB indicada con -m no existe: $matlab_dir${reset}"
  exit 1
fi


# Chequeo opcional de dependencias

for cmd in mrconvert mrinfo flirt DenoiseImage matlab; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${rojo}Error: no se encontró el comando requerido '$cmd' en PATH${reset}"
    exit 1
  fi
done

echo -e "${azul}======= Preparación de imágenes para MTSat =======${reset}"

# === Función para leer scaling (offset, multiplier) ===
get_scaling() {
  local img="$1"
  local line
  line="$(mrinfo "$img" 2>/dev/null | sed -n 's/.*Intensity scaling: offset = \([^,]*\), multiplier = \(.*\)$/\1,\2/p' | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    echo "0,1"
  else
    echo "$line" | tr -d ' '
  fi
}

extract_tr() {
  grep -A 1 "##\$ACQ_repetition_time=" "$1" | tail -n 1 | tr -d ' ()'
}

extract_flip() {
  grep "##\$ACQ_flip_angle=" "$1" | cut -d= -f2 | tr -d ' ,'
}

check_and_fix_datatype() {
  local input="$1"
  local dtype
  dtype=$(mrinfo "$input" | grep "Data type" | awk -F: '{print $2}' | xargs)

  if [[ "$dtype" != "32 bit float (little endian)" ]]; then
    echo -e "${amarillo}Convirtiendo $input a 32-bit float SIN modificar intensidades...${reset}"
    mrconvert "$input" -datatype float32 -quiet "${input%.nii.gz}_float32.nii.gz"
    mv "${input%.nii.gz}_float32.nii.gz" "$input"
    echo -e "${verde}-> Tipo de dato actualizado a float32.${reset}"
  else
    echo -e "${verde}$input ya está en float32.${reset}"
  fi
}


# 1) Separación de volúmenes

echo -e "${amarillo}[1/7] Separando volúmenes desde $pd_mtsat...${reset}"
mrconvert "$pd_mtsat" imagen_sin_saturacion.nii.gz -coord 3 0 || exit 1
mrconvert "$pd_mtsat" imagen_con_saturacion.nii.gz -coord 3 1 || exit 1


# 2) Lectura de scaling

echo -e "${amarillo}[2/7] Leyendo Intensity scaling...${reset}"

sc_mtoff="$(get_scaling imagen_sin_saturacion.nii.gz)"
sc_mton="$(get_scaling imagen_con_saturacion.nii.gz)"
sc_t1="$(get_scaling "$t1_img")"

off_mtoff="${sc_mtoff%,*}"; mul_mtoff="${sc_mtoff#*,}"
off_mton="${sc_mton%,*}";   mul_mton="${sc_mton#*,}"
off_t1="${sc_t1%,*}";       mul_t1="${sc_t1#*,}"

echo -e "${verde}➤ MToff: offset=$off_mtoff | multiplier=$mul_mtoff${reset}"
echo -e "${verde}➤ MTon : offset=$off_mton  | multiplier=$mul_mton${reset}"
echo -e "${verde}➤ T1   : offset=$off_t1    | multiplier=$mul_t1${reset}"


# 3) Registro

echo -e "${amarillo}[3/7] Registrando imágenes con FLIRT...${reset}"
flirt -in imagen_con_saturacion.nii.gz -ref imagen_sin_saturacion.nii.gz -out imagen_con_saturacion_registrada.nii.gz -dof 7 || exit 1
flirt -in "$t1_img" -ref imagen_sin_saturacion.nii.gz -out imagen_T1_registrada.nii.gz -dof 7 || exit 1


# 4) Reaplicar scaling tras FLIRT

echo -e "${amarillo}[4/7] Reaplicando scaling tras FLIRT...${reset}"
mrconvert imagen_con_saturacion_registrada.nii.gz imagen_con_satu_reg_fix.nii.gz -datatype int16 -scaling 0,"$mul_mtoff" || exit 1
mrconvert imagen_T1_registrada.nii.gz imagen_T1_reg_fix.nii.gz -datatype int16 -scaling 0,"$mul_t1" || exit 1


# 5) Extracción de parámetros

echo -e "${amarillo}[5/7] Extrayendo TR y flip angle desde archivos acqp...${reset}"

TRPD=$(extract_tr "$acqp_pd")
TRT1=$(extract_tr "$acqp_t1")
alphPD=$(extract_flip "$acqp_pd")
alphT1=$(extract_flip "$acqp_t1")

echo -e "${verde}➤ TR (PD): $TRPD ms${reset}"
echo -e "${verde}➤ Flip Angle (PD): $alphPD°${reset}"
echo -e "${verde}➤ TR (T1): $TRT1 ms${reset}"
echo -e "${verde}➤ Flip Angle (T1): $alphT1°${reset}"


# 6) Denoising

echo -e "${amarillo}[6/7] Aplicando denoising con DenoiseImage...${reset}"

DenoiseImage -d 3 -i imagen_sin_saturacion.nii.gz -o imagen_sin_pulso_denoiseada.nii.gz || exit 1
DenoiseImage -d 3 -i imagen_con_satu_reg_fix.nii.gz -o imagen_con_pulso_denoiseada.nii.gz || exit 1
DenoiseImage -d 3 -i imagen_T1_reg_fix.nii.gz -o T1_denoi.nii.gz || exit 1

echo -e "${verde}Denoising completado correctamente.${reset}"

# --- Reaplicar scaling tras Denoise ---
mrconvert imagen_sin_pulso_denoiseada.nii.gz imagen_sin_pulso_den_fix.nii.gz -datatype int16 -scaling 0,"$mul_mton" || exit 1
mrconvert imagen_con_pulso_denoiseada.nii.gz imagen_con_pulso_den_fix.nii.gz -datatype int16 -scaling 0,"$mul_mtoff" || exit 1
mrconvert T1_denoi.nii.gz imagen_T1_den_fix.nii.gz -datatype int16 -scaling 0,"$mul_t1" || exit 1


# 7) Preparar B1 y ejecutar MATLAB

echo -e "${amarillo}[7/7] Ejecutando MATLAB para calcular MTSat...${reset}"

b1_basename=$(basename "$b1_map")


if [[ -z "$alphPD" || -z "$alphT1" || -z "$TRPD" || -z "$TRT1" || -z "$b1_basename" ]]; then
  echo -e "${rojo}Error: alguna variable requerida está vacía.${reset}"
  echo "alphPD=$alphPD | alphT1=$alphT1 | TRPD=$TRPD | TRT1=$TRT1 | b1_map=$b1_basename"
  exit 1
fi

if [[ -n "$matlab_dir" ]]; then
  matlab_addpath="addpath('$matlab_dir'); "
else
  matlab_addpath=""
fi

echo ""
echo "MATLAB recibirá los siguientes parámetros:"
echo "  - MTon: imagen_con_pulso_den_fix.nii.gz"
echo "  - MToff: imagen_sin_pulso_den_fix.nii.gz"
echo "  - T1w: imagen_T1_den_fix.nii.gz"
echo "  - B1map: $b1_basename"
echo "  - Filtro gaussiano: $gaussianFilter"
echo "  - Flip Angles: $alphPD (PD), $alphT1 (T1)"
echo "  - TRs: $TRPD (PD), $TRT1 (T1)"
echo ""

matlab -batch "\
addpath('$matlab_dir'); \
disp('Ruta de nii2mtsat:'); \
which('nii2mtsat'); \
disp('Ejecutando nii2mtsat...'); \
nii2mtsat('imagen_con_pulso_den_fix', \
          'imagen_sin_pulso_den_fix', \
          'imagen_T1_den_fix', \
          '$(basename "$b1_map" .nii.gz)', \
          $gaussianFilter, \
          $alphPD, $alphT1, $TRPD, $TRT1); \
disp('MTSat generado correctamente');"
catch ME; \
  disp('Error en nii2mtsat:'); \
  disp(getReport(ME)); \
  exit(1); \
end; \
exit(0);" || {
  echo -e "${rojo}Error: MATLAB reportó un problema durante la ejecución de nii2mtsat.${reset}"
  exit 1
}

echo -e "${verde}Proceso de MTSat finalizado correctamente.${reset}"
echo -e "${azul}MTSat generado. Verifica los resultados.${reset}"
