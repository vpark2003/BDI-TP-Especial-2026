
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
