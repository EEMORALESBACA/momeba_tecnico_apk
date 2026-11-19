# Momeba Técnico

App Android para los técnicos de campo de **Grupo Momeba**. Usa el mismo Firebase
(`momeba-servicio`) y el mismo servidor de HostGator que el panel web `servicio.html`.

## Qué hace
- Entrada con contraseña y **Google Authenticator** (verificado en `api.php?m=seguridad`); vuelve a pedir el código tras 2 horas sin actividad.
- Servicios asignados: aceptar, en camino (con navegación), en sitio, QR de verificación para el cliente.
- Cierre completado, pendiente o cancelado con fotos, firma del cliente y **hoja de servicio PDF**.
- Fotos, firma, video y PDF se suben a HostGator (`api.php?m=archivos`), por partes de 4 MB.
- Ubicación para el mapa del panel (también en segundo plano, cada 15 min, solo con servicios activos).
- Ruta del día, productividad, crédito y refacciones de almacén, **Descargas** (software de la marca y explosionados).

## Estructura
- `momeba_tecnico/`: la app Flutter.
- `packages/momeba_core/`: modelos, acceso a datos y generador del PDF.
- `.github/workflows/build-apk.yml`: GitHub compila el APK en cada cambio (pestaña **Actions** → descarga `momeba-tecnico-apk`).

## Antes de compilar
1. En Firebase (proyecto `momeba-servicio`) registrar la app Android `com.grupomomeba.tecnico` y copiar
   `google-services.json` en `momeba_tecnico/android/app/`.
2. (Opcional, recomendado) Firma fija para que cada versión se instale encima de la anterior:
   agregar en GitHub → Settings → Secrets → Actions: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.

El servidor se configura en `packages/momeba_core/lib/src/config.dart` (`https://grupomomeba.com/servicio`).

## Ruta y llegada (estilo reparto)

- **Estoy llegando**: en el detalle (o marcando varias paradas en *Ruta del día*) eliges en cuánto llegas. La orden pasa a *En camino*, el cliente ve la hora en su página de seguimiento y se abre WhatsApp con el aviso y su liga.
- **Llegada automática**: con la orden *En camino*, al estar a menos de 100 m del domicilio pasa sola a *En sitio*, aunque la app esté minimizada.
- **Ruta del día**: paradas ordenadas (más lejano primero o ruta más corta), órdenes del mismo domicilio agrupadas, ruta completa en Google Maps, y secciones de próximas, por aceptar y terminadas hoy.
- **Foto del lugar**: si el técnico marca la llegada a mano a más de 250 m del domicilio (o sin GPS), la app pide una foto de la fachada como comprobante; el panel la muestra en la ficha.

## Más mejoras

- **Bloques de visita**: el panel programa por bloques de 2 horas (por ejemplo 10:00 a 12:00); el técnico y el cliente los ven.
- **Ubicación validada**: cuando el GPS detecta la llegada, el domicilio queda validado; la próxima orden del mismo teléfono toma esa ubicación y el técnico ve el sello "Ubicación validada".
- **Capacitación**: en Descargas, tarjeta "Capacitación" con las lecciones que publica el coordinador (tipo "Capacitación"), el avance en % y cuáles ya viste. El panel ve quién las vio.
