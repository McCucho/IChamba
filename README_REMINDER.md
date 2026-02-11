# Recordatorio: reanudar debugging RLS y posts

Cuando vuelvas a iniciar Visual Studio Code recuerda:

- Revisar tipos de columnas en la BD (`users`, `posts`).
- Revisar errores 400 en la petición de `upsert` (abrir DevTools → Network).
- Probar publicar/editar/eliminar publicaciones desde la app.
- Ejecutar en SQL Editor (si falta):

  SELECT table_name, column_name, data_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name IN ('users','posts')
  ORDER BY table_name, column_name;

Marcá esto como completado cuando hayas retomado.
