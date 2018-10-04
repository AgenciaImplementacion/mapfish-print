WITH 
t AS (
	SELECT t_id, ST_ForceRHR(poligono_creado) as poligono_creado FROM canutalito_20180829.terreno AS t WHERE t.t_id = 1438
),
a AS (
	SELECT ST_MakePoint(st_xmin(t.poligono_creado), st_ymax(t.poligono_creado)) AS p FROM t
),
b AS (
	SELECT ST_MakePoint(st_xmax(t.poligono_creado), st_ymax(t.poligono_creado)) AS p FROM t
),
c AS (
	SELECT ST_MakePoint(st_xmax(t.poligono_creado), st_ymin(t.poligono_creado)) AS p FROM t
),
d AS (
	SELECT ST_MakePoint(st_xmin(t.poligono_creado), st_ymin(t.poligono_creado)) AS p FROM t
),
m AS (
	--SELECT ST_MakePoint(st_x(ST_centroid(st_envelope(t.poligono_creado))), st_y(ST_centroid(st_envelope(t.poligono_creado)))) AS p FROM t
	SELECT ST_MakePoint(st_x(ST_centroid(t.poligono_creado)), st_y(ST_centroid(t.poligono_creado))) AS p FROM t
),
norte AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [a.p, b.p, m.p, a.p])), ST_SRID(t.poligono_creado)) geom FROM t,a,b,m
),
este AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [m.p, b.p, c.p, m.p])), ST_SRID(t.poligono_creado)) geom FROM t,b,c,m
),
sur AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [m.p, c.p, d.p, m.p])), ST_SRID(t.poligono_creado)) geom FROM t,m,c,d
),
oeste AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [a.p, m.p, d.p, a.p])), ST_SRID(t.poligono_creado)) geom FROM t,a,m,d
),
/*
linderos_cubiertos_por_terreno as (
	SELECT 
		l.t_id as lindero_id
		,t.t_id as terreno_id
		,geometria as lindero_geometria
	FROM t
	JOIN canutalito_20180829.lindero l ON st_covers(poligono_creado,geometria)
),*/
/*
linderos as (
	select linderos_cubiertos_por_terreno.lindero_id
		,t_id
		,nombre 
		,lindero_geometria

	from linderos_cubiertos_por_terreno 
	left join 
	(
		select 
			lindero_id
			,colindantes.t_id 
			,coalesce(predio.numero_predial,predio.nombre,predio.nupre) nombre 
		from linderos_cubiertos_por_terreno 
		JOIN canutalito_20180829.masccl vuelta ON lindero_id = vuelta.cclp_lindero
		JOIN canutalito_20180829.terreno colindantes ON vuelta.uep_terreno = colindantes.t_id  AND colindantes.t_id <> terreno_id
		JOIN canutalito_20180829.uebaunit ON colindantes.t_id = ue_terreno
		JOIN canutalito_20180829.predio ON predio.t_id = baunit_predio
	) a on linderos_cubiertos_por_terreno.lindero_id = a.lindero_id
),
*/
linderos AS (
	select 
		colindantes.t_id
		,coalesce(predio.numero_predial,predio.nombre,predio.nupre) nombre 
		,lindero_geometria
		,lindero_id
	 from
	(
	  select t.t_id terreno_id,l.t_id as lindero_id ,l.geometria as lindero_geometria FROM t
		JOIN canutalito_20180829.masccl ida ON ida.uep_terreno = t.t_id
		JOIN canutalito_20180829.lindero l ON cclp_lindero = l.t_id
	) l
	LEFT JOIN canutalito_20180829.masccl vuelta ON vuelta.cclp_lindero = lindero_id and vuelta.uep_terreno <>  terreno_id
	LEFT JOIN canutalito_20180829.terreno colindantes ON colindantes.t_id = vuelta.uep_terreno
	LEFT JOIN canutalito_20180829.uebaunit ON uebaunit.ue_terreno = colindantes.t_id
	LEFT JOIN canutalito_20180829.predio ON predio.t_id = uebaunit.baunit_predio
),
colindantes_opt_1 AS (
	SELECT sentido,nombre,lindero_id FROM 
	(
		SELECT *,st_length(st_intersection(geom, lindero_geometria)) dist, max(st_length(st_intersection(geom, lindero_geometria))) over (partition by nombre) max_dist
		FROM (
			SELECT 'Norte' sentido,* FROM linderos,norte WHERE st_intersects(norte.geom, linderos.lindero_geometria)
			UNION
			SELECT 'Este' sentido,* FROM linderos,este WHERE st_intersects(este.geom, linderos.lindero_geometria)
			UNION
			SELECT 'Sur' sentido,* FROM linderos,sur WHERE st_intersects(sur.geom, linderos.lindero_geometria)
			UNION
			SELECT 'Oeste' sentido,* FROM linderos,oeste WHERE st_intersects(oeste.geom, linderos.lindero_geometria)
		) f
	) a
	where dist = max_dist
	ORDER BY array_position(Array ['Norte','Este','Sur','Oeste'], sentido), degrees(st_azimuth(ST_centroid(geom), ST_ClosestPoint(geom,lindero_geometria)))
),
puntos_terreno as (
	SELECT (ST_DumpPoints(poligono_creado)).* AS dp
		,poligono_creado
	FROM t
), 
punto_inicial_noroccidental as(
	select st_startpoint(lindero_geometria) geom,
	st_distance(st_startpoint(lindero_geometria), ST_SetSRID(ST_MakePoint(st_xmin(st_envelope(poligono_creado)), st_ymax(st_envelope(poligono_creado))), ST_SRID(poligono_creado))) AS dist from linderos,t order by dist limit 1 
), 
punto_inicial as (
	SELECT row_number() OVER (ORDER BY path) AS m
			,st_intersects(puntos_terreno.geom,a.geom) inicial
			FROM puntos_terreno, (select puntos_terreno.geom from punto_inicial_noroccidental, puntos_terreno where st_intersects(punto_inicial_noroccidental.geom,puntos_terreno.geom)) a
			order by inicial DESC NULLS LAST limit 1
),
puntos_ordenados as (
SELECT case when id-m+1 <= 0 then total + id-m else id-m+1 end as id, geom , st_x(geom) x, st_y(geom) y FROM
	(
		SELECT row_number() OVER (ORDER BY path) AS id
			,m
			,path
			,geom
			,total
		FROM (
			SELECT (ST_DumpPoints(ST_ForceRHR(poligono_creado))).* AS dp
				,ST_NPoints(poligono_creado) total
				,poligono_creado
			FROM t
			) AS a
			,punto_inicial
	) t
	where id <> total
	order by id
)
, poligono_ordenado as (
	select ST_SetSRID(ST_MakePolygon(ST_MakeLine(array_agg(geom))), ST_SRID(t.poligono_creado)) geom 
	FROM (
		select * from (
			select * from puntos_ordenados order by id
		) a 
		union all
		select * from (
			select * from puntos_ordenados order by id limit 1
		) b
	) a,
	t group by poligono_creado
)
,inicio_fin_linderos as
(
	select st_startpoint(lindero_geometria) geom from linderos
	union
	select st_endpoint(lindero_geometria) geom from linderos
),
puntos_inicio_lindero as (
	select 
		row_number() OVER (ORDER BY idx) as id, idx
	from
	(
		select ST_LineLocatePoint(a.geom, inicio_fin_linderos.geom) as idx from
		(
			select ST_LineMerge(ST_Boundary(geom)) as geom from poligono_ordenado
		)a, inicio_fin_linderos order by idx
	) a
),
indices_inicio_lindero as (
	select a.idx as desde, b.idx as hasta from puntos_inicio_lindero a,puntos_inicio_lindero b where a.id = b.id-1
	union
	select a.idx as desde, b.idx as hasta from puntos_inicio_lindero a,puntos_inicio_lindero b where a.id = (select max(id) from puntos_inicio_lindero) and b.id = 1
	order by desde
)
, linderosRHR as (
	select ST_LineSubstring(geom,desde,hasta) geom
	from
	(
		select ST_LineMerge(ST_Boundary(geom)) as geom from poligono_ordenado
	) a,
	(
		select a.idx as desde, b.idx as hasta from puntos_inicio_lindero a,puntos_inicio_lindero b where a.id = b.id-1
		union
		select a.idx as desde, 1 as hasta from puntos_inicio_lindero a,puntos_inicio_lindero b where a.id = (select max(id) from puntos_inicio_lindero) and b.id = 1
		order by desde
	) b
)
--select * from linderosRHR



,cruce_puntosOrdenados_linderos as (
	select id,x,y,lindero_id,geom from puntos_ordenados,linderos where st_intersects(puntos_ordenados.geom,st_startpoint(lindero_geometria)) or st_intersects(puntos_ordenados.geom,st_endpoint(lindero_geometria)) order by puntos_ordenados.id 
)
,minmax_lindero as (
	select min(id), max(id) from cruce_puntosOrdenados_linderos
)
,linderos_ordenados as (
	select * from
	(
		select distinct on(a.lindero_id) a.id desde ,b.id hasta,a.lindero_id, a.geom as geom_desde, b.geom as geom_hasta  from cruce_puntosOrdenados_linderos a , cruce_puntosOrdenados_linderos b, minmax_lindero 
		where a.lindero_id = b.lindero_id and a.id <> b.id and a.id = minmax_lindero.min and b.id <> minmax_lindero.max
		order by a.lindero_id,a.id,b.id 
	) a
	UNION
	(
		select distinct on(a.lindero_id) a.id desde ,b.id hasta,a.lindero_id, a.geom as geom_desde, b.geom as geom_hasta  from cruce_puntosOrdenados_linderos a , cruce_puntosOrdenados_linderos b, minmax_lindero 
		where a.lindero_id = b.lindero_id and a.id <> b.id and a.id <> minmax_lindero.min and b.id <> minmax_lindero.min
		order by a.lindero_id,a.id,b.id 
	)  
	UNION
	select * from
	(
		select distinct on(a.lindero_id) a.id desde ,b.id hasta,a.lindero_id, a.geom as geom_desde, b.geom as geom_hasta  from cruce_puntosOrdenados_linderos a , cruce_puntosOrdenados_linderos b, minmax_lindero 
		where a.lindero_id = b.lindero_id and a.id <> b.id and a.id = minmax_lindero.max and b.id = minmax_lindero.min
		order by a.lindero_id,a.id,b.id 
	) b
	order by desde
)
select linderos_ordenados.*
	--,sentido
	, linderos.nombre
	, lindero_geometria 
	from linderos_ordenados 
	--left join colindantes_opt_1 on linderos_ordenados.lindero_id = colindantes_opt_1.lindero_id
	left join linderos on linderos_ordenados.lindero_id = linderos.lindero_id
order by linderos_ordenados.desde



/*
select * from puntos_terreno,
(
select st_startpoint(lindero_geometria) a, st_endpoint(lindero_geometria) b from linderos, punto_noroccidental a where st_intersects(geometria,geom)
)a 
where st_intersects(geom,a) or st_intersects(geom,b)
*/



/*
--ok: encontrar si el punto noroccidental es punto inicial o punto medio de lindero
select case when st_intersects(geom,a) or st_intersects(geom,b) then 'inicial' else 'medio' end from punto_noroccidental
,
(select st_startpoint(lindero_geometria) a, st_endpoint(lindero_geometria) b from linderos, punto_noroccidental a where st_intersects(geometria,geom)) a
*/

/*
select min(dist) from
(
	select st_distance(inicio,geom) dist, geom from
	(
	  select ST_StartPoint(geometria) inicio, ST_EndPoint(geometria) fin, * from linderos
	) start_end
	,
	(
	SELECT row_number() OVER (ORDER BY path) AS m
		,st_distance(geom, ST_SetSRID(ST_MakePoint(st_xmin(st_envelope(poligono_creado)), st_ymax(st_envelope(poligono_creado))), ST_SRID(poligono_creado))) AS dist
		,geom
		FROM (
			SELECT (ST_DumpPoints(ST_ForceRHR(poligono_creado))).* AS dp
				,poligono_creado
			FROM t 
			) AS a
		ORDER BY dist limit 1
	) nw
) a*/