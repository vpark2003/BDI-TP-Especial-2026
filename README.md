# BDI-TP-Especial-2026
Trabajo Práctico Especial - Base de Datos I - ITBA

# Trabajo Práctico Especial — Base de Datos I

**Instituto Tecnológico de Buenos Aires (ITBA)**  
**Segundo cuatrimestre de 2026**

## Descripción

Este proyecto implementa una base de datos PostgreSQL para administrar los vehículos, mecánicos, asignaciones y órdenes de trabajo de un taller mecánico. Incluye restricciones declarativas, triggers para validar reglas de negocio y una función para generar reportes de órdenes cerradas.

## Archivos del proyecto

| Archivo | Descripción |
| --- | --- |
| `funciones.sql` | Creación de tablas, restricciones, funciones, triggers e importación de datos. |
| `asignacion.csv` | Datos iniciales de vehículos, mecánicos y asignaciones. |
| `orden.csv` | Datos iniciales de órdenes de trabajo. |
| `TPEspecial2026-2.pdf` | Enunciado del trabajo práctico. |
| `README.md` | Documentación del proyecto. |

## Modelo de datos

Se utilizan cuatro tablas principales:

- **`vehiculo`**: patente, marca y modelo.
- **`mecanico`**: legajo, nombre y especialidad.
- **`asignacion`**: relación entre vehículos y mecánicos, con fecha de asignación.
- **`orden`**: órdenes de trabajo, con vehículo, mecánico, descripción, fechas y horas trabajadas.

El script también crea una tabla temporal `asignacion_plana` para importar los datos iniciales y distribuirlos entre las tablas correspondientes.

## Validaciones y triggers

- **`controlar_especialidad_asignacion`** (`verificar_especialidad_asignacion`): impide asignar al mismo vehículo dos mecánicos de una misma especialidad.
- **`controlar_cambio_especialidad`** (`verificar_cambio_especialidad`): impide cambios de especialidad que produzcan conflictos en las asignaciones existentes.
- **`controlar_orden`** (`verificar_orden`): comprueba que el mecánico esté asignado al vehículo al registrar una orden, impide modificar órdenes cerradas, evita que una orden en curso vuelva a abierta y prohíbe que un mecánico tenga más de una orden en curso simultáneamente.

La función auxiliar **`estado_orden(p_nro)`** determina si una orden está `abierta`, `en curso` o `cerrada`.

Además, la tabla `orden` contiene restricciones `CHECK` para validar la coherencia de las fechas y las horas trabajadas.

## Reporte del taller

La función **`reporte_taller(p_desde DATE, p_hasta DATE)`** genera, mediante mensajes `NOTICE`, un reporte de órdenes cerradas en el período indicado.

Agrupa los resultados por especialidad y mecánico, informa la cantidad de órdenes y horas trabajadas, y calcula subtotales y totales.

Ejemplo de uso:

```sql
SELECT reporte_taller('2026-01-01', '2026-12-31');
```

## Ejecución

**Requisitos:** PostgreSQL y acceso a una base de datos con permisos para crear tablas, funciones y triggers.

1. Abrir `funciones.sql`.
2. Ajustar las rutas de los archivos CSV en las dos instrucciones `COPY` para que sean rutas absolutas accesibles desde el servidor PostgreSQL. Las instrucciones `COPY` requieren los permisos correspondientes en el servidor.
3. Ejecutar el script desde `psql`:

```bash
psql -h SERVIDOR -U USUARIO -d BASE_DE_DATOS -f funciones.sql
```

**Atención:** el script comienza con instrucciones `DROP TABLE`, que eliminan las tablas indicadas y sus datos si ya existen. Ejecutarlo únicamente en el esquema y la base de datos destinados al trabajo práctico.

