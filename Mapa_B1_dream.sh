#!/bin/bash
# Codigo para obtener RFlocal
#Autor: Yessenia Garcia Rizo
echo "=========================================="
echo "      Generación de mapa B1 con QI"
echo "=========================================="

# Volumen STE
echo "Ingrese el nombre del volumen STE (ejemplo: STE.nii.gz):"
read vol_STE
if [ ! -f "$vol_STE" ]; then
    echo " Error: El archivo $vol_STE no existe."
    exit 1
fi

# Volumen FID
echo "Ingrese el nombre del volumen FID (ejemplo: FID.nii.gz):"
read vol_FID
if [ ! -f "$vol_FID" ]; then
    echo " Error: El archivo $vol_FID no existe."
    exit 1
fi

# Archivo method del mapa B1
echo "Ingrese la ruta del archivo 'method' correspondiente al mapa B1:"
read archivo_method
if [ ! -f "$archivo_method" ]; then
    echo "Error: El archivo $archivo_method no existe."
    exit 1
fi

# --- Extraer el valor de ##$SteamPulse ---
echo ""
echo "Buscando variable ##\$SteamPulse= en $archivo_method..."

# Buscar la línea que contiene ##$SteamPulse=
linea=$(grep "##\$SteamPulse=" "$archivo_method")

if [ -z "$linea" ]; then
    echo "No se encontró la variable ##\$SteamPulse= en el archivo method."
    exit 1
fi
valor_tercero=$(echo "$linea" | sed 's/.*(//' | sed 's/).*//' | awk '{print $3}' | tr -d ',' | xargs)
if [ -z "$valor_tercero" ]; then
    echo " No se pudo extraer el tercer valor de ##\$SteamPulse="
    exit 1
fi

echo " 	El valor teorico es ##\$SteamPulse: $valor_tercero"

echo ""
echo "Concatenando volúmenes FID y STE..."
mrcat -axis 3 "$vol_FID" "$vol_STE" dream_file.nii.gz

if [ $? -ne 0 ]; then
    echo "Error al concatenar las imágenes con mrcat."
    exit 1
fi
echo "Archivo concatenado generado: dream_file.nii.gz"

# --- Crear mapa B1 con QI ---
echo ""
echo "Creando mapa B1 con QI..."
qi dream  dream_file.nii.gz --out=prefixdream --order=f -a "$valor_tercero"

if [ $? -ne 0 ]; then
    echo "Error al generar el mapa B1 con qi."
    exit 1
fi

echo "Mapa B1 generado exitosamente: prefixdream_B1map.nii.gz (u otros archivos generados)"
echo ""
echo "   Proceso completado correctamente"

