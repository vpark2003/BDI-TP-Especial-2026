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

-- ===== IMPORTACION =====

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
FROM '/ruta completa a asignacion.csv'
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

COPY orden
FROM 'ruta completa a orden.csv'
CSV HEADER;

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
      AND a.legajo <> NEW.legajo;

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