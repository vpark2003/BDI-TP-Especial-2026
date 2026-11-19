DROP TABLE IF EXISTS mecanico CASCADE;
DROP TABLE IF EXISTS vehiculo CASCADE;
DROP TABLE IF EXISTS asignacion CASCADE;
DROP TABLE IF EXISTS orden CASCADE;
DROP TABLE IF EXISTS asignacion_plana;

CREATE TABLE vehiculo
(
  patente VARCHAR(10) NOT NULL,
  marca VARCHAR(30),
  modelo VARCHAR(30),
  PRIMARY KEY (patente)
);

CREATE TABLE mecanico
(
  legajo  INT NOT NULL,
  nombre  VARCHAR(50),
  especialidad  VARCHAR(20),
  PRIMARY KEY (legajo),
  CHECK (especialidad IN ('Motor', 'Frenos', 'Electricidad', 'Suspensión'))
);

CREATE TABLE asignacion
(
  patente   VARCHAR(10) NOT NULL,
  legajo    INT NOT NULL,
  fecha_asignacion DATE,
  PRIMARY KEY (patente, legajo),
  FOREIGN KEY (patente) REFERENCES vehiculo,
  FOREIGN KEY (legajo)  REFERENCES mecanico
);

CREATE TABLE orden
(
  nro_orden INT NOT NULL,
  patente   VARCHAR(10) NOT NULL,
  legajo    INT NOT NULL,
  descripcion       VARCHAR(100),
  fecha_apertura    DATE NOT NULL,
  fecha_inicio DATE,
  fecha_cierre DATE,
  horas DECIMAL(4,1),
  PRIMARY KEY (nro_orden),
  FOREIGN KEY (patente) REFERENCES vehiculo,
  FOREIGN KEY (legajo)  REFERENCES mecanico,
  CHECK (fecha_inicio >= fecha_apertura),
  CHECK (fecha_cierre IS NULL OR (fecha_inicio IS NOT NULL AND fecha_cierre >= fecha_inicio)),
  CHECK ((fecha_cierre IS NULL AND horas IS NULL) OR (fecha_cierre IS NOT NULL AND horas IS NOT NULL AND horas > 0))
);

-- Trigger: control de especialidades en asignaciones

CREATE OR REPLACE FUNCTION verificar_especialidad_asignacion()
RETURNS TRIGGER AS $$
DECLARE
    cantidad INT;
BEGIN
    SELECT COUNT(*) INTO cantidad
    FROM asignacion a
    JOIN mecanico m1 ON a.legajo = m1.legajo
    JOIN mecanico m2 ON m2.legajo = NEW.legajo
    WHERE a.patente = NEW.patente
      AND m1.especialidad = m2.especialidad
      AND a.legajo <> NEW.legajo
      AND NOT (
          TG_OP = 'UPDATE'
          AND a.patente = OLD.patente
          AND a.legajo = OLD.legajo
      );

    IF cantidad > 0 THEN
        RAISE EXCEPTION 'Ya existe un mecanico de esa especialidad asignado al vehiculo';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER controlar_especialidad_asignacion
BEFORE INSERT OR UPDATE ON asignacion
FOR EACH ROW
EXECUTE PROCEDURE verificar_especialidad_asignacion();

-- Trigger: control de cambios de especialidad en mecanicos

CREATE OR REPLACE FUNCTION verificar_cambio_especialidad()
RETURNS TRIGGER AS $$
DECLARE
    cantidad INT;
BEGIN
    SELECT COUNT(*) INTO cantidad
    FROM asignacion a1
    JOIN asignacion a2 ON a1.patente = a2.patente
    JOIN mecanico m ON a2.legajo = m.legajo
    WHERE a1.legajo = NEW.legajo
      AND a2.legajo <> NEW.legajo
      AND m.especialidad = NEW.especialidad;

    IF cantidad > 0 THEN
        RAISE EXCEPTION 'El cambio de especialidad genera conflictos en las asignaciones';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER controlar_cambio_especialidad
BEFORE UPDATE ON mecanico
FOR EACH ROW
EXECUTE PROCEDURE verificar_cambio_especialidad();

-- Funcion: reporte de ordenes cerradas del taller

CREATE OR REPLACE FUNCTION reporte_taller(p_desde DATE, p_hasta DATE)
RETURNS VOID AS $$
DECLARE
    mi_cursor CURSOR FOR
        SELECT m.especialidad, m.legajo, m.nombre,
               COUNT(*) AS cantidad_ordenes,
               SUM(o.horas) AS total_horas
        FROM orden o
        JOIN mecanico m ON o.legajo = m.legajo
        WHERE o.fecha_cierre BETWEEN p_desde AND p_hasta
        GROUP BY m.especialidad, m.legajo, m.nombre
        ORDER BY m.especialidad, total_horas DESC, m.legajo;

    fila RECORD;

    especialidad_anterior VARCHAR(20);

    subtotal_ordenes INT := 0;
    subtotal_horas NUMERIC := 0;

    total_ordenes INT := 0;
    total_horas NUMERIC := 0;

    cantidad INT;

BEGIN
    IF p_desde > p_hasta THEN
        RAISE EXCEPTION 'La fecha inicial no puede ser posterior a la fecha final';
    END IF;

    SELECT COUNT(*) INTO cantidad
    FROM orden
    WHERE fecha_cierre BETWEEN p_desde AND p_hasta;

    IF cantidad = 0 THEN
        RETURN;
    END IF;

    RAISE NOTICE '======== REPORTE DE ÓRDENES CERRADAS ========';
    RAISE NOTICE 'Período: % a %', p_desde, p_hasta;

    OPEN mi_cursor;

    LOOP
        FETCH mi_cursor INTO fila;
        EXIT WHEN NOT FOUND;

        IF especialidad_anterior IS NULL OR
           especialidad_anterior <> fila.especialidad THEN

            IF especialidad_anterior IS NOT NULL THEN
                RAISE NOTICE '-- subtotal %: % órdenes, % h',
                    especialidad_anterior, subtotal_ordenes, subtotal_horas;
            END IF;

            RAISE NOTICE '== Especialidad: % ==', fila.especialidad;

            especialidad_anterior := fila.especialidad;

            subtotal_ordenes := 0;
            subtotal_horas := 0;

        END IF;

        RAISE NOTICE '[%] % - % órdenes - % h',
            fila.legajo,
            fila.nombre,
            fila.cantidad_ordenes,
            fila.total_horas;

        subtotal_ordenes := subtotal_ordenes + fila.cantidad_ordenes;
        subtotal_horas := subtotal_horas + fila.total_horas;

        total_ordenes := total_ordenes + fila.cantidad_ordenes;
        total_horas := total_horas + fila.total_horas;

    END LOOP;

    CLOSE mi_cursor;

    RAISE NOTICE '-- subtotal %: % órdenes, % h',
        especialidad_anterior, subtotal_ordenes, subtotal_horas;

    RAISE NOTICE '======== TOTAL: % órdenes, % h ========',
        total_ordenes, total_horas;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION estado_orden(p_nro INT)
RETURNS TEXT AS $$
DECLARE
    v_fecha_inicio DATE;
    v_fecha_cierre DATE;
BEGIN
    SELECT fecha_inicio, fecha_cierre
    INTO v_fecha_inicio, v_fecha_cierre
    FROM orden
    WHERE nro_orden = p_nro;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden % no existe', p_nro;
    END IF;

    IF v_fecha_cierre IS NOT NULL THEN
        RETURN 'cerrada';

    ELSIF v_fecha_inicio IS NOT NULL THEN
        RETURN 'en curso';

    ELSE
        RETURN 'abierta';
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Funcion del trigger: valida las reglas de negocio
CREATE OR REPLACE FUNCTION verificar_orden()
RETURNS TRIGGER AS $$
DECLARE
    cantidad INT;
BEGIN

    -- Regla 1: el mecanico debe estar asignado al vehiculo
    -- al registrar la orden
    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*) INTO cantidad
        FROM asignacion
        WHERE patente = NEW.patente
          AND legajo = NEW.legajo;

        IF cantidad = 0 THEN
            RAISE EXCEPTION
                'El mecanico no esta asignado al vehiculo';
        END IF;
    END IF;


    IF TG_OP = 'UPDATE' THEN

        -- Regla 2: una orden cerrada no puede modificarse
        IF estado_orden(OLD.nro_orden) = 'cerrada' THEN
            RAISE EXCEPTION
                'No se puede modificar una orden cerrada';
        END IF;

        -- Regla 3: una orden en curso no puede volver a abierta
        IF estado_orden(OLD.nro_orden) = 'en curso'
           AND NEW.fecha_inicio IS NULL THEN
            RAISE EXCEPTION
                'Una orden en curso no puede volver a abierta';
        END IF;

    END IF;


    -- Regla 4: un mecanico no puede tener
    -- mas de una orden en curso simultaneamente
    IF NEW.fecha_inicio IS NOT NULL
       AND NEW.fecha_cierre IS NULL THEN

        SELECT COUNT(*) INTO cantidad
        FROM orden
        WHERE legajo = NEW.legajo
          AND fecha_inicio IS NOT NULL
          AND fecha_cierre IS NULL
          AND nro_orden <> NEW.nro_orden;

        IF cantidad > 0 THEN
            RAISE EXCEPTION
                'El mecanico ya tiene otra orden en curso';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER controlar_orden
BEFORE INSERT OR UPDATE ON orden
FOR EACH ROW
EXECUTE PROCEDURE verificar_orden();

-- ===== IMPORTACION =====
-- Va al final para que los triggers ya existan y se ejecuten durante la carga.

CREATE TEMP TABLE asignacion_plana
(
  patente VARCHAR(10),
  marca VARCHAR(30),
  modelo VARCHAR(30),
  legajo INT,
  nombre_mecanico VARCHAR(50),
  especialidad VARCHAR(20),
  fecha_asignacion DATE
);

-- reemplazar la ruta por la ruta completa al archivo en su computadora
COPY asignacion_plana
FROM '/ruta/completa/a/asignacion.csv'
CSV HEADER;

INSERT INTO vehiculo
SELECT DISTINCT patente, marca, modelo
FROM asignacion_plana;

INSERT INTO mecanico
SELECT DISTINCT legajo, nombre_mecanico, especialidad
FROM asignacion_plana;

INSERT INTO asignacion
SELECT patente, legajo, fecha_asignacion
FROM asignacion_plana;

-- reemplazar la ruta por la ruta completa al archivo en su computadora
COPY orden
FROM '/ruta/completa/a/orden.csv'
CSV HEADER;
