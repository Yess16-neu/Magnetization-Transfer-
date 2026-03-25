#!/usr/bin/env bash

Usage() {
    cat <<USAGE
Usage:
  $(basename "$0") -p PD_MTSAT -t T1_IMG -b B1_MAP -a ACQP_PD -A ACQP_T1 [-g GAUSSIAN] [-s SCRIPT]

Example:
  $(basename "$0") \
    -p /ruta/sag_FLASH_PD_Mtsat.nii.gz \
    -t /ruta/sag_FLASH_T1.nii.gz \
    -b /ruta/prefixdreamDREAM_B1.nii.gz \
    -a /ruta/acqp_PD.txt \
    -A /ruta/acqp_T1.txt \
    -g 0 \
    -s MTSAT.sh # script base 

Compulsory arguments:
  -p    Archivo sag_FLASH_PD_Mtsat.nii.gz
  -t    Archivo sag_FLASH_T1.nii.gz
  -b    Archivo B1 map (prefixdreamDREAM_B1.nii.gz)
  -a    Archivo acqp de imagen PD_Mtsat
  -A    Archivo acqp de imagen T1

Optional arguments:
  -g    Valor del filtro gaussiano (default = 0)
  -s    Ruta al script original (default = ./mtsat_original.sh)
  -h    Mostrar esta ayuda



USAGE
    exit 1
}

# Defaults
gaussian="0"
script="./mtsat_original.sh"

# Parse args
while getopts ":p:t:b:a:A:g:s:h" opt; do
    case "$opt" in
        p) pd_mtsat="$OPTARG" ;;
        t) t1_img="$OPTARG" ;;
        b) b1_map="$OPTARG" ;;
        a) acqp_pd="$OPTARG" ;;
        A) acqp_t1="$OPTARG" ;;
        g) gaussian="$OPTARG" ;;
        s) script="$OPTARG" ;;
        h) Usage ;;
        \?)
            echo "Error: opción inválida -$OPTARG" >&2
            Usage
            ;;
        :)
            echo "Error: la opción -$OPTARG requiere un argumento." >&2
            Usage
            ;;
    esac
done

# Validate compulsory args
[[ -z "$pd_mtsat" ]] && { echo "Error: falta -p"; Usage; }
[[ -z "$t1_img"   ]] && { echo "Error: falta -t"; Usage; }
[[ -z "$b1_map"   ]] && { echo "Error: falta -b"; Usage; }
[[ -z "$acqp_pd"  ]] && { echo "Error: falta -a"; Usage; }
[[ -z "$acqp_t1"  ]] && { echo "Error: falta -A"; Usage; }

# Validate script
if [[ ! -f "$script" ]]; then
    echo "Error: no se encontró el script original: $script" >&2
    exit 1
fi

if [[ ! -x "$script" ]]; then
    echo "Aviso: el script no tiene permisos de ejecución. Intentando con bash..."
    runner=(bash "$script")
else
    runner=("$script")
fi

# Validate files
for f in "$pd_mtsat" "$t1_img" "$b1_map" "$acqp_pd" "$acqp_t1"; do
    if [[ ! -f "$f" ]]; then
        echo "Error: no se encontró el archivo '$f'" >&2
        exit 1
    fi
done

# Validate gaussian numeric
if ! [[ "$gaussian" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: -g debe ser un número válido." >&2
    exit 1
fi

# Execute original script, feeding answers to its read prompts
{
    printf '%s\n' "$pd_mtsat"
    printf '%s\n' "$t1_img"
    printf '%s\n' "$b1_map"
    printf '%s\n' "$acqp_pd"
    printf '%s\n' "$acqp_t1"
    printf '%s\n' "$gaussian"
} | "${runner[@]}"