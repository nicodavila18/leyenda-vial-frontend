# 🛡️ Leyenda Vial App

Una aplicación móvil colaborativa para reportar incidentes viales en tiempo real, diseñada para mejorar la seguridad en las rutas argentinas. Combina geolocalización precisa, gamificación y un modelo de suscripción premium.

> **Estado:** 🚀 En Producción (Desplegado en Railway)

## 📱 Capturas de Pantalla

| Mapa en Vivo | Reporte de Incidente | Modo Premium |
|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/cf7f3e40-453c-4cb8-a4c8-0e0c2c10ab63" width="200"> | <img src="https://github.com/user-attachments/assets/e4ed0179-dee6-4f4e-b4ba-23bc92306ecf" width="200"> | <img src="https://github.com/user-attachments/assets/dc4599b5-8308-4641-bd3f-07487f894545" width="200"> |

## ⚡ Características Principales

* **🗺️ Mapa en Tiempo Real:** Integración con **Mapbox** para visualización de alta performance.
* **📢 Reportes Comunitarios:** Los usuarios pueden reportar:
    * 🚓 Controles Policiales
    * 🚗 Accidentes
    * 🚧 Obras en construcción
* **⛽ Sistema "Tanque de Nafta":** Lógica inteligente que limita a 3 reportes diarios para usuarios gratuitos (anti-spam).
* **💎 Suscripción Premium:** Integración nativa con **MercadoPago** para pagos recurrentes, desbloqueando reportes ilimitados.
* **📍 Puntos de Interés:** Carga automática de Hospitales y Comisarías en un radio de 60km usando datos de OpenStreetMap.
* **🎮 Gamificación:** Sistema de XP y Reputación. Los usuarios suben de rango (Novato -> Leyenda) al confirmar reportes reales.

## 🛠️ Tecnologías Utilizadas

### Frontend (Móvil)
* **Framework:** Flutter (Dart)
* **Mapas:** Mapbox GL
* **Pagos:** UrlLauncher (Integración Deep Link con MercadoPago)
* **Estado:** Provider / Stateful Widgets

### Backend (API)
* **Lenguaje:** Python
* **Framework:** FastAPI
* **Base de Datos:** PostgreSQL (Alojada en **Neon Tech**)
* **Hosting:** Railway
* **Geoespacial:** PostGIS (Cálculo de distancias en metros y radios de búsqueda)

## 🚀 Instalación y Despliegue

### Requisitos Previos
* Flutter SDK instalado.
* Dispositivo Android o Emulador.

### Configuración
1.  Clonar el repositorio:
    ```bash
    git clone [https://github.com/TU_USUARIO/seguridad_vial_app.git](https://github.com/TU_USUARIO/seguridad_vial_app.git)
    ```
2.  Instalar dependencias:
    ```bash
    flutter pub get
    ```
3.  Ejecutar la App:
    ```bash
    flutter run
    ```

## 🔐 Variables de Entorno
El proyecto requiere claves de API para funcionar (Mapbox, MercadoPago, Neon DB). Estas no se incluyen en el repositorio por seguridad.

---
Hecho con 💚 por Nicolás Dávila en Mendoza, Argentina.
