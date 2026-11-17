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
