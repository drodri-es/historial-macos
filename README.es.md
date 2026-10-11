# Historial

[English](README.md)

Historial es una pequeña aplicación nativa de macOS para guardar copias recientes del portapapeles. Vive en la barra de menús y se abre con un atajo global configurable (**⌥V** por defecto). Conserva texto, imágenes y referencias a archivos, con búsqueda y vistas previas.

> Versión preliminar. La descarga no está firmada ni notarizada por Apple. El atajo global y el pegado automático aún requieren una comprobación manual con los permisos necesarios de macOS.

## Descarga

Descarga el ZIP para Mac con Apple Silicon desde [Releases](https://github.com/drodri-es/historial-macos/releases), descomprímelo y mueve `Historial.app` a Aplicaciones. Requiere macOS 15 o posterior. Esta compilación no funciona en Mac con procesador Intel.

Como la app no está firmada con un ID de desarrollador de Apple, macOS puede bloquear la primera apertura. Después de intentar abrirla, entra en **Ajustes del Sistema → Privacidad y seguridad** y pulsa **Abrir igualmente** para Historial. Consulta las [instrucciones de Apple](https://support.apple.com/es-es/guide/mac-help/-mh40616/mac). Autoriza la excepción solo si confías en la descarga.

## Funciones

- Restaura la entrada seleccionada al portapapeles e intenta pegarla en la aplicación que estaba activa.
- Permite buscar copias y muestra vistas previas de texto, imágenes y archivos.
- Conserva el historial entre sesiones, con límite de entradas y caducidad configurables.
- Permite pausar la captura, excluir aplicaciones por identificador y borrar el historial.
- Ofrece la interfaz en castellano, inglés o el idioma del sistema, con cambio inmediato.
- Guarda los datos en este Mac; no incluye sincronización ni funciones de red.

Las entradas de archivos guardan sus rutas originales. Historial no mueve ni modifica los archivos; si desaparecen de su ubicación original, no podrá restaurarlos.

## Compilar y abrir

Se necesita macOS 15 o posterior y las herramientas de línea de comandos de Apple. En un Mac:

```sh
zsh scripts/build-app.sh
open dist/Historial.app
```

El script crea `dist/Historial.app` con una firma local ad hoc. No genera una versión notarizada para distribución. La app generada y la caché de compilación están excluidas de Git.

## Permisos y alternativa

macOS puede solicitar acceso al portapapeles cuando Historial lee copias en segundo plano. Para pegar automáticamente en la aplicación anterior, también necesita permiso de **Accesibilidad** en Ajustes del Sistema. Si no lo concedes, al elegir una entrada queda restaurada en el portapapeles: pulsa **⌘V** en la aplicación de destino para pegarla manualmente.

## Uso

1. Copia texto, una imagen o un archivo en otra aplicación.
2. Pulsa **⌥V** o haz clic en el icono del portapapeles de la barra de menús.
3. Busca y selecciona una entrada. También puedes usar **↑/↓** y **Retorno**.
4. Abre **Ajustes** para cambiar el atajo, idioma, límites, caducidad, pausa o aplicaciones excluidas.

El historial se guarda solo en `~/Library/Application Support/Historial/history.json`. Usa **Borrar historial** en Ajustes para eliminar las entradas guardadas.

## Código

- `Sources/Historial/App.swift`: barra de menús, atajo y pegado.
- `Sources/Historial/Core.swift`: captura del portapapeles y persistencia local.
- `Sources/Historial/UI.swift`: panel del historial y ajustes.
- `Sources/Historial/Resources`: textos en inglés y castellano.
- `scripts/build-app.sh`: compilación local de la aplicación.

## Licencia

MIT. Consulta [`LICENSE`](LICENSE).
