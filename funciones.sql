DROP TABLE IF EXISTS mecanico CASCADE;
DROP TABLE IF EXISTS vehiculo CASCADE;
DROP TABLE IF EXISTS asignacion CASCADE;
DROP TABLE IF EXISTS orden CASCADE;

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
  FOREIGN KEY (legajo)  REFERENCES mecanico
);