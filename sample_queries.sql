/* ------------------------------------------------------------
Consultas, modificaciones, borrados y vistas con enunciado
---------------------------------------------------------------*/
/*Consultas de caracterización*/
-- Listado de eventos
select
	 id_evento
    ,nombre_evento
    ,precio_ticket
    ,fecha
    ,descripcion
from swellevents.evento;

-- Listado de actividades
select
	 a.id_actividad
    ,a.nombre_actividad
    ,a.coste
    ,ta.nombre_tipo_actividad as tipo_actividad
from swellevents.actividad a
left join tipo_actividad ta on ta.id_tipo_actividad = a.id_tipo_actividad;

-- Listado de actividades ordenado por el coste de la actividad descendente, indicando tipo de actividad
select
	 a.id_actividad
    ,a.nombre_actividad
    ,a.coste
    ,ta.nombre_tipo_actividad as tipo_actividad
from swellevents.actividad a
left join tipo_actividad ta on ta.id_tipo_actividad = a.id_tipo_actividad
order by coste desc;

-- Listado de asistentes con más de un teléfono de contacto
select 
	 a.id_asistente
    ,a.nombre1
    ,a.nombre2
    ,a.apellido1
    ,a.apellido2
    ,a.email
    ,count(ta.numero_telefono) as cantidad_telefonos
from swellevents.asistente a
left join swellevents.telefono_asistente ta on ta.id_asistente = a.id_asistente
group by
	 a.id_asistente
    ,a.nombre1
    ,a.nombre2
    ,a.apellido1
    ,a.apellido2
    ,a.email
having cantidad_telefonos > 1
order by cantidad_telefonos desc;    
    

/*Consultas de análisis*/
/*Select*/
-- Hay eventos que realicen la misma actividad
-- Versión con agregación normal
select
	 max(datos_evt.id_evento) as id_evento
	,max(datos_evt.nombre_evento) as nombre_evento
	,datos_evt.nombre_actividad
    ,count(datos_evt.nombre_actividad) as count_actividad
from(    
	select
		 e.id_evento
        ,e.nombre_evento 
        ,a.nombre_actividad
	from swellevents.evento e
	left join swellevents.actividad a on a.id_actividad = e.id_actividad
	)datos_evt
group by datos_evt.nombre_actividad
having count_actividad > 1;

-- Versión con agregación analítica
select
	*
from(    
	select
		 e.id_evento
		,e.nombre_evento
		,e.precio_ticket
		,e.fecha
		,a.nombre_actividad
		,count(a.id_actividad) over(partition by a.id_actividad) as count_actividad
	from swellevents.evento e
	left join swellevents.actividad a on a.id_actividad = e.id_actividad
	)datos_evt
where datos_evt.count_actividad > 1;

-- Promedio de venta de tickets de eventos
select
	avg(dat.total_venta_tickets) as promedio_venta_tickets_eventos
from(    
	select
		 e.id_evento
		,e.nombre_evento
		,e.precio_ticket
		,count(a.id_asistente) cantidad_asistentes
		,sum(e.precio_ticket) total_venta_tickets
		-- ,a.id_asistente
		-- ,a.nombre1
		-- ,a.apellido1
	from swellevents.evento e
	left join swellevents.evento_asistente ea on ea.id_evento = e.id_evento
	left join swellevents.asistente a on a.id_asistente = ea.id_asistente
	group by 
		 e.id_evento
		,e.nombre_evento
		,e.precio_ticket
	)dat;

-- Listado de eventos mostrando su recaudación por tickets vendido y comparando su % sobre el promedio de los eventos
select
	 base.*
    ,prom.*
    ,round(((base.total_venta_tickets / promedio_venta_tickets_eventos)-1) * 100, 2) as porcentaje_venta_tickets_sobre_promedio
from(
	select
		 e.id_evento
		,e.nombre_evento
		,e.precio_ticket
		,count(a.id_asistente) cantidad_asistentes
		,sum(e.precio_ticket) total_venta_tickets
	from swellevents.evento e
	left join swellevents.evento_asistente ea on ea.id_evento = e.id_evento
	left join swellevents.asistente a on a.id_asistente = ea.id_asistente
	group by 
		 e.id_evento
		,e.nombre_evento
		,e.precio_ticket
	)base
join (
select
	  round(sum(e.precio_ticket) / count(distinct e.id_evento), 2) promedio_venta_tickets_eventos
from swellevents.evento e
left join swellevents.evento_asistente ea on ea.id_evento = e.id_evento
left join swellevents.asistente a on a.id_asistente = ea.id_asistente
)prom on 1=1; -- Como para todos los eventos el % de ventas es el mismo, se implementó un producto cartesiano. Lo optimo sería usar funciones analíticas.


-- Hay eventos donde no se han vendido tickets?
-- Respuesta: No. Todos los eventos tienen al menos 1 asistente.
select
	  *
from swellevents.evento e
left join swellevents.evento_asistente ea on ea.id_evento = e.id_evento
where ea.id_evento is null;


-- hay actividades que no tienen eventos programados?
-- Respuesta: Si. Las siguientes actividades no tienen eventos programados
select
	  *
from swellevents.actividad a
left join swellevents.evento e on a.id_actividad = e.id_actividad
where e.id_actividad is null;

/*Vista*/
-- Vista general sobre los eventos
-- Muestra el detalle de los eventos y sus principales metricas de performance, tales como:
-- Porcentaje de tickets vendidos (total de tickets venditos / aforo permitido por la ubicación (máximo de tickets que se pueden vender))
-- Rentabilidad del evento (suma total de la recaudación / coste de la actividad asociada al evento (los eventos con coste 0 son eventos de caridad, por lo que muestran rentabilidad 0, es decir, toda la recaudación se dona a la caridad)
CREATE OR REPLACE VIEW v_vista_general_eventos AS
SELECT
	 e.id_evento
    ,e.nombre_evento
    ,ac.nombre_actividad
    ,u.nombre_ubicacion
    ,u.aforo as cnt_tickets_disponibles
    ,count(a.id_asistente) cnt_tickets_vendidos
    ,round((count(a.id_asistente) / u.aforo)*100, 2) prc_tickets_vendidos
    ,ac.coste as coste_evento
	,e.precio_ticket
	,round((count(a.id_asistente) * e.precio_ticket), 2) as dinero_recaudado
    ,case when ac.coste = 0.00 then 0.00 else round((((count(a.id_asistente) * e.precio_ticket) / ac.coste)-1)*100, 2) end as rentabilidad_evento
FROM swellevents.evento e
LEFT JOIN swellevents.ubicacion u on u.id_ubicacion = e.id_ubicacion
LEFT JOIN swellevents.actividad ac on ac.id_actividad = e.id_actividad
LEFT JOIN swellevents.evento_asistente ea on ea.id_evento = e.id_evento
LEFT JOIN swellevents.asistente a on a.id_asistente = ea.id_asistente
group by 
	 e.id_evento
    ,e.nombre_evento
    ,ac.nombre_actividad
    ,u.nombre_ubicacion
    ,u.aforo
    ,ac.coste
	,e.precio_ticket;

-- Listado general de eventos
SELECT * FROM swellevents.v_vista_general_eventos;

-- Listado de eventos de caridad
SELECT * FROM swellevents.v_vista_general_eventos vge WHERE vge.coste_evento = 0;

-- Listado de eventos rentables
SELECT * FROM swellevents.v_vista_general_eventos vge WHERE vge.rentabilidad_evento >= 100;

-- Listado de eventos no rentables (la suma de los tickets vendidos no alcanza a cubrir los costes)
SELECT * FROM swellevents.v_vista_general_eventos vge WHERE vge.rentabilidad_evento < 100;


--

/*Update*/
-- Se define en sesión especial del directorio de la Universidad Complutense de Madrid lo siguiente:
-- El actual estadio "Estadio UCM" se pasará a llamar "Estadio Mario Vargas LLosa" en honor a uno de sus ilustres premios novel.

UPDATE swellevents.ubicacion u
SET u.nombre_ubicacion = 'Estadio Mario Vargas LLosa'
WHERE u.id_ubicacion = 8;

-- Se utiliza el vista general de eventos para validar el cambio
SELECT * FROM swellevents.v_vista_general_eventos;


/*Delete*/
-- La productora de eventos "Eventos UCM" tomó la desición de no ofrecer mas la actividad "Conferencia" debido al poco interés del público. 
-- SELECT * FROM swellevents.tipo_actividad WHERE id_tipo_actividad = 4;

-- Se elimina el registro
DELETE FROM swellevents.tipo_actividad WHERE id_tipo_actividad = 4;

-- Se valida la operación de eliminación
SELECT * FROM swellevents.tipo_actividad WHERE id_tipo_actividad = 4;

-- Si se quiere volver a cargar el registro eliminado, acá está el insert:
-- INSERT INTO tipo_actividad(id_tipo_actividad, nombre_tipo_actividad) VALUES ('4', 'Conferencia');



/*Triggers*/
-- Valida que no se ingresen mas asistentes al evento de lo que permita el aforo asociado a la ubicación.
DELIMITER //
CREATE TRIGGER valida_aforo_ubicacion BEFORE INSERT ON swellevents.evento_asistente
	FOR EACH ROW
	BEGIN
		DECLARE v_aforo_ubicacion INT;
        DECLARE v_cantidad_asistentes INT;
        
        -- Inicializa variable: v_aforo_ubicacion
        SELECT u.aforo INTO v_aforo_ubicacion 
        FROM swellevents.ubicacion u 
        WHERE u.id_ubicacion = (
			SELECT e.id_ubicacion 
            FROM swellevents.evento e 
            WHERE e.id_evento = NEW.id_evento
            );
        
        -- Inicializa variable: v_cantidad_asistentes
        SELECT count(ea.id_asistente) INTO v_cantidad_asistentes
        FROM swellevents.evento_asistente ea
        WHERE ea.id_evento = NEW.id_evento;
            
        IF (v_cantidad_asistentes + 1) > v_aforo_ubicacion
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede ingresar mas asistentes a este evento. Se ha alcanzado aforo máximo.';  
			-- TODO: (Opcional) Rollback de la operación de inserción del asistente en la tabla swellevents.asistente
            --       Yo no lo eliminaría, ya que así me quedo con los datos personales del asistente que podrían servir para otro tipo de análisis en el futuro.
		END IF;  
	END;//
DELIMITER ;    
    
-- Inserta un asistente a un evento pero que excede el aforo de la ubicación donde se realizará el evento.
--     Genera error a propósito al gatillar la excepción del triger: valida_aforo_ubicacion de la tabla evento_asistente
INSERT INTO evento_asistente(id_evento_asistente, id_evento, id_asistente) VALUES ('2707', '1', '131');
