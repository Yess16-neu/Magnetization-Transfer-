#!/bin/bash
# Codigo para obtener mapa MTSAT
#Autor: Yessenia Garcia Rizo

# === Colores ===
verde="\033[1;32m"
rojo="\033[1;31m"
amarillo="\033[1;33m"
azul="\033[1;34m"
reset="\033[0m"

echo -e "${azul}======= Preparación de imágenes para MTSat =======${reset}"

# === Solicitar rutas ===
read -e -p "Archivo sag_FLASH_PD_Mtsat.nii.gz: " pd_mtsat
read -e -p "Archivo sag_FLASH_T1.nii.gz: " t1_img
read -e -p "Archivo B1 map (prefixdreamDREAM_B1.nii.gz): " b1_map
read -e -p "Archivo acqp de imagen PD_Mtsat: " acqp_pd
read -e -p "Archivo acqp de imagen T1: " acqp_t1

# === Validar existencia de archivos ===
for f in "$pd_mtsat" "$t1_img" "$b1_map" "$acqp_pd" "$acqp_t1"; do
  if [ ! -f "$f" ]; then
    echo -e "${rojo} Error: No se encontró el archivo '$f'${reset}"
    exit 1
  fi
done


# === Función para leer scaling (offset, multiplier)       ===
get_scaling(){
  local img="$1"
  local line
  line="$(mrinfo "$img" 2>/dev/null | sed -n 's/.*Intensity scaling: offset = \([^,]*\), multiplier = \(.*\)$/\1,\2/p' | head -n 1 || true)"
  if [[ -z "${line}" ]]; then
    echo "0,1"
  else
    echo "${line}" | tr -d ' '
  fi
}

# === Separación de volúmenes ===
echo -e "${amarillo}Separando volúmenes desde $pd_mtsat...${reset}"
mrconvert "$pd_mtsat" imagen_sin_saturacion.nii.gz -coord 3 0
mrconvert "$pd_mtsat" imagen_con_saturacion.nii.gz -coord 3 1


# === NUEVO: Tomar scaling DESDE las imágenes ya separadas ===
echo -e "${amarillo}Leyendo Intensity scaling (desde volúmenes separados y T1)...${reset}"

sc_mtoff="$(get_scaling imagen_sin_saturacion.nii.gz)"
sc_mton="$(get_scaling imagen_con_saturacion.nii.gz)"
sc_t1="$(get_scaling "$t1_img")"

off_mtoff="${sc_mtoff%,*}"; mul_mtoff="${sc_mtoff#*,}"
off_mton="${sc_mton%,*}";   mul_mton="${sc_mton#*,}"
off_t1="${sc_t1%,*}";       mul_t1="${sc_t1#*,}"

echo -e "${verde}  ➤ MToff (sin saturación): offset=$off_mtoff | multiplier=$mul_mtoff${reset}"
echo -e "${verde}  ➤ MTon  (con saturación): offset=$off_mton  | multiplier=$mul_mton${reset}"
echo -e "${verde}  ➤ T1 (input):             offset=$off_t1    | multiplier=$mul_t1${reset}"

# === Registro (12 grados de libertad) ===
echo -e "${amarillo}Registrando imágenes al espacio con saturación (FLIRT - dof 7)...${reset}"
flirt -in imagen_con_saturacion.nii.gz -ref imagen_sin_saturacion.nii.gz -out imagen_con_saturacion_registrada.nii.gz -dof 7
flirt -in "$t1_img" -ref imagen_sin_saturacion.nii.gz -out imagen_T1_registrada.nii.gz -dof 7


# --- Reaplicar scaling tras FLIRT ---
mrconvert  imagen_con_saturacion_registrada.nii.gz imagen_con_satu_reg_fix.nii.gz  -datatype int16 -scaling 0,$mul_mtoff

mrconvert  imagen_T1_registrada.nii.gz imagen_T1_reg_fix.nii.gz  -datatype int16 -scaling 0,$mul_t1


# === Funciones auxiliares (post-registro y scaling OK)   ===


extract_tr () {
  grep -A 1 "##\$ACQ_repetition_time=" "$1" | tail -n 1 | tr -d ' ()'
}

extract_flip () {
  grep "##\$ACQ_flip_angle=" "$1" | cut -d= -f2 | tr -d ' ,'
}

check_and_fix_datatype () {
  local input="$1"
  dtype=$(mrinfo "$input" | grep "Data type" | awk -F: '{print $2}' | xargs)

  if [[ "$dtype" != "32 bit float (little endian)" ]]; then
    echo -e "${amarillo}Convirtiendo $input a 32-bit float SIN modificar intensidades...${reset}"


    mrconvert "$input" -datatype float32 -quiet "${input%.nii.gz}_float32.nii.gz"
    mv "${input%.nii.gz}_float32.nii.gz" "$input"

    echo -e "${verde}  -> Tipo de dato actualizado a float32 (intensidades intactas).${reset}"
  else
    echo -e "${verde} $input ya está en float32.${reset}"
  fi
}


# === Extracción de parámetros de adquisición 


echo -e "${amarillo}Extrayendo TR y flip angle desde archivos acqp...${reset}"

TRPD=$(extract_tr "$acqp_pd")
TRT1=$(extract_tr "$acqp_t1")
alphPD=$(extract_flip "$acqp_pd")
alphT1=$(extract_flip "$acqp_t1")

echo -e "${verde}  ➤ TR (PD):  $TRPD ms${reset}"
echo -e "${verde}  ➤ Flip Angle (PD): $alphPD°${reset}"
echo -e "${verde}  ➤ TR (T1):  $TRT1 ms${reset}"
echo -e "${verde}  ➤ Flip Angle (T1): $alphT1°${reset}"

# === Denoising (post-registro, post-scaling, float32 OK) ===

echo -e "${amarillo}Aplicando denoising con DenoiseImage...${reset}"

# MT sin pulso
DenoiseImage -d 3 \
  -i imagen_sin_saturacion.nii.gz \
  -o imagen_sin_pulso_denoiseada.nii.gz

# MT con pulso
DenoiseImage -d 3 \
  -i imagen_con_satu_reg_fix.nii.gz  \
  -o imagen_con_pulso_denoiseada.nii.gz

# T1
DenoiseImage -d 3 \
  -i imagen_T1_reg_fix.nii.gz \
  -o T1_denoi.nii.gz

echo -e "${verde} Denoising completado correctamente.${reset}"

# --- Reaplicar scaling tras Denoise ---
mrconvert   imagen_sin_pulso_denoiseada.nii.gz imagen_sin_pulso_den_fix.nii.gz  -datatype int16 -scaling 0,$mul_mton
mrconvert   imagen_con_pulso_denoiseada.nii.gz imagen_con_pulso_den_fix.nii.gz  -datatype int16 -scaling 0,$mul_mtoff
mrconvert  T1_denoi.nii.gz imagen_T1_den_fix.nii.gz  -datatype int16 -scaling 0,$mul_t1

# === Filtro gaussiano ===
read -p "Valor del filtro gaussiano (por defecto 0): " gaussianFilter
gaussianFilter=${gaussianFilter:-0}

# === Preparar B1map ===
b1_basename=$(basename "$b1_map")
cp "$b1_map" .

echo ""
echo -e "${azul} Ejecutando código MATLAB para calcular MTSat...${reset}"
echo "MATLAB recibirá los siguientes parámetros:"
echo "  - MTon: imagen_con_pulso_den_fix.nii.gz"
echo "  - MToff: imagen_sin_pulso_den_fix.nii.gz"
echo "  - T1w: imagen_T1_den_fix.nii.gz"
echo "  - B1map: $b1_basename"
echo "  - Filtro gaussiano: $gaussianFilter"
echo "  - Flip Angles: $alphPD (PD), $alphT1 (T1)"
echo "  - TRs: $TRPD (PD), $TRT1 (T1)"
echo ""

# === Verificación de variables ===
if [[ -z "$alphPD" || -z "$alphT1" || -z "$TRPD" || -z "$TRT1" || -z "$b1_basename" ]]; then
  echo -e "${rojo} Error: Alguna variable requerida está vacía.${reset}"
  echo "Valores actuales:"
  echo "alphPD=$alphPD | alphT1=$alphT1 | TRPD=$TRPD | TRT1=$TRT1 | b1_map=$b1_basename"
  exit 1
fi

# === Llamada a MATLAB ===
matlab -nodisplay -nosplash -r "\
try; \
  disp('Llamando a nii2mtsat con parámetros:'); \
  disp({'imagen_con_pulso_den_fix.nii.gz','imagen_sin_pulso_den_fix.nii.gz','imagen_T1_den_fix.nii.gz','$b1_basename',$gaussianFilter,$alphPD,$alphT1,$TRPD,$TRT1}); \
  nii2mtsat('imagen_con_pulso_den_fix', \
            'imagen_sin_pulso_den_fix', \
            'imagen_T1_den_fix', \
            '$(basename "$b1_map" .nii.gz)', \
            $gaussianFilter, \
            $alphPD, $alphT1, $TRPD, $TRT1); \
  disp(' MTSat generado correctamente.'); \
catch ME; \
  disp(' Error en nii2mtsat:'); \
  disp(getReport(ME)); \
  exit(1); \
end; \
exit(0);"

if [ $? -eq 0 ]; then
  echo -e "${verde} Proceso de MTSat finalizado correctamente.${reset}"
else
  echo -e "${rojo} Error: MATLAB reportó un problema durante la ejecución de nii2mtsat.${reset}"
  exit 1
fi
echo -e "${azul}  MTSat generado. Verifica los resultados.  ${reset}"



 


