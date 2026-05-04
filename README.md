# Proyecto Final Cloud Computing 

### 1. Sistema de Matrícula Universitaria con Alta Disponibilidad

**Servicios:** EC2 + ALB + Auto Scaling + RDS Multi-AZ + Lambda + SES

**Descripción:** Plataforma donde estudiantes se matriculan en cursos. El ALB distribuye carga entre instancias EC2 (NGINX + app), RDS en Multi-AZ garantiza disponibilidad de datos, y una Lambda envía confirmación de matrícula por email con Amazon SES.

**Complejidad adicional:** Configurar Auto Scaling Groups que escalen ante carga alta, simular fallos de AZ y comprobar que RDS hace failover automático.

- El ALB debe tener **reglas de enrutamiento por path:** /admin/* va a un Target Group de instancias EC2 con NGINX configurado como reverse proxy hacia la app, /api/* va directo a Lambda mediante ALB-Lambda integration (no API Gateway).
    
- RDS debe estar en **Multi-AZ con réplica de lectura:** las consultas de disponibilidad de cupos (alta frecuencia) deben ir obligatoriamente al endpoint de lectura; las matrículas al endpoint principal. La aplicación debe manejar ambos endpoints.

- Auto Scaling debe usar **políticas de escalado por pasos** (step scaling), no simple. Definir dos umbrales: al 60% CPU escala +1 instancia, al 85% escala +3 instancias. Demostrar el comportamiento con pruebas de carga usando Apache Benchmark o similar desde la misma EC2.

- Lambda de confirmación debe reintentar el envío por SES con **backoff exponencial** si SES devuelve throttling, y registrar el fallo en RDS si supera 3 reintentos.

---

### 2.  Plataforma de Telemedicina con Videoconferencia y Expedientes

**Servicios:** S3 + Lambda + API Gateway + RDS + CloudFront + Cognito

**Descripción:** Pacientes suben documentos médicos cifrados a S3, una Lambda indexa los metadatos en RDS (MYSQL), Cognito gestiona roles (médico/paciente), y CloudFront sirve el frontend con restricción geográfica.

**Complejidad adicional:** Implementar presigned URLs con expiración corta, cifrado del bucket S3 con KMS, y políticas IAM basadas en roles de Cognito.

- Cognito debe tener dos **User Pools separados** (médicos y pacientes) con atributos personalizados distintos. Los tokens JWT deben incluir claims personalizados (custom:role, custom:license) que la Lambda Authorizer de API Gateway lee para decidir qué endpoints puede llamar cada rol.

- S3 debe usar **cifrado SSE-KMS con clave gestionada por el cliente (CMK)**. La clave KMS debe tener una política de clave que solo permita el acceso al rol IAM de Lambda, no al rol de la consola. Demostrar que un acceso directo desde consola es denegado.

- CloudFront debe servir el frontend con **dos comportamientos** de caché distintos: archivos estáticos con TTL de 1 día, respuestas de API (/api/*) con TTL 0 y headers de autorización en la whitelist.

- Las presigned URLs de S3 deben generarse con **duración dinámica** según el tipo de documento: imágenes diagnósticas 5 minutos, informes 1 hora. Lambda debe validar que el sub del token Cognito coincide con el patientId del documento antes de generar la URL.

---

### 3. Marketplace con Procesamiento de Pagos y Notificaciones

**Servicios:** EC2 + ALB + Lambda + RDS + SQS + SNS + S3

**Descripción:** Vendedores publican productos (imágenes en S3, datos en RDS). Las órdenes entran por API Gateway → Lambda → SQS. Otra Lambda consume la cola, procesa el pago (simulado) y publica en SNS para notificar por email/SMS.

- Implementar el patrón **Fan-out:** SNS tiene tres suscriptores distintos cuando llega una orden: (1) SQS cola de procesamiento de pago, (2) SQS cola de notificación al vendedor, (3) Lambda directa para actualizar inventario en RDS. Cada suscriptor debe tener un filter policy en SNS para recibir solo los mensajes que le corresponden según el tipo de evento.

- La cola principal de SQS debe tener configurada una **Dead Letter Queue** (DLQ) con maxReceiveCount: 3. Una Lambda separada debe monitorear la DLQ cada 5 minutos via EventBridge, leer los mensajes fallidos, registrar el error en RDS y notificar al administrador por SNS.

- EC2 con NGINX debe estar configurado como **reverse proxy con upstream ponderado:** 70% del tráfico al servidor de la app principal, 30% a una instancia "canary" con la versión nueva. Demostrar el cambio de pesos sin downtime.

- Las imágenes de productos en S3 deben pasar por una **Lambda de validación** (tamaño máximo, formato permitido, sin contenido explícito usando Rekognition) antes de quedar disponibles. Si la validación falla, mover el objeto a un prefijo /rejected/ y notificar al vendedor.

---

### 4. Sistema de Monitoreo IoT para Campus Universitario

**Servicios:** API Gateway + Lambda + DynamoDB + S3 + CloudWatch + SNS

**Descripción:** Sensores simulados (temperatura, ocupación de aulas) envían datos cada minuto a API Gateway. Lambda procesa y almacena en DynamoDB con TTL. CloudWatch Alarms detectan anomalías y SNS envía alertas. Dashboard en S3 + CloudFront visualiza datos en tiempo real.

**Complejidad adicional:** Implementar DynamoDB Streams que activen una Lambda al detectar valores críticos.

- DynamoDB debe usar un **modelo de acceso dual:** tabla principal con sensorId como PK y timestamp como SK para escrituras, más un GSI con buildingId como PK y timestamp como SK para consultas por edificio. La Lambda debe elegir el índice correcto según el patrón de consulta recibido.

- Configurar **DynamoDB Streams** conectado a una Lambda que analice los últimos 10 registros del mismo sensor: si la tendencia es sostenidamente creciente (temperatura subiendo 0.5°C por lectura), debe publicar en SNS aunque el valor actual no supere el umbral absoluto. Implementar la lógica de detección de tendencia en la misma Lambda.

 - CloudWatch debe tener un **dashboard programático** (creado via SDK, no consola) con widgets de métricas customizadas que la Lambda publica con put_metric_data. Demostrar que las métricas custom aparecen en el dashboard.

 - El frontend en S3 debe consumir datos usando **API Gateway con caché habilitado** (TTL 30 segundos para consultas históricas, 0 para tiempo real). Demostrar la diferencia de latencia y costo entre ambos endpoints.

---

### 5. Plataforma de Streaming de Contenido Educativo

**Servicios:** S3 + CloudFront + Lambda + MediaConvert + RDS + ALB + EC2

**Descripción:** Profesores suben videos a S3. Un evento S3 PutObject activa Lambda que lanza un job en AWS Elemental MediaConvert para transcodificar a HLS (múltiples calidades). CloudFront sirve el contenido con signed cookies para usuarios autenticados. EC2 + ALB hospedan el portal web con reproductor adaptativo.

**Complejidad adicional:** Configurar CloudFront con OAC (Origin Access Control) para que solo CloudFront acceda al bucket.

- El evento S3 debe activar una **Lambda Step 1** que valide el video (duración máxima, formato), registre el job en RDS con estado PENDING, y luego llame a MediaConvert. Una segunda Lambda conectada al **EventBridge de MediaConvert** debe actualizar el estado en RDS a PROCESSING → READY conforme avanzan los estados del job. El frontend no muestra el video hasta que RDS confirme estado READY.

- MediaConvert debe generar **tres rendiciones HLS:** 1080p, 720p y 360p, más un thumbnail cada 30 segundos. Los segmentos .ts y los manifiestos .m3u8 deben ir a un prefijo diferente en S3 que el video original.

- CloudFront debe configurarse con **Signed Cookies** (no Signed URLs) para que el reproductor pueda cargar múltiples segmentos HLS sin autenticarse en cada request. La Lambda que sirve el frontend genera la cookie firmada con una clave privada RSA almacenada en Secrets Manager.

- EC2 con NGINX debe configurar headers de seguridad obligatorios (Strict-Transport-Security, X-Content-Type-Options, Content-Security-Policy) y actuar como reverse proxy añadiendo el header X-User-Id extraído del JWT antes de pasar la solicitud a la app, para que la app no tenga que procesar el token.

---

### 6. Asistente de Código para Estudiantes con IA Generativa
    
**Servicios:** API Gateway + Lambda + Amazon Bedrock + DynamoDB + S3 + Cognito

**Descripción:** Estudiantes envían código o preguntas de programación. Lambda llama a Amazon Bedrock (Claude/Titan) para revisar el código, detectar errores y sugerir mejoras. El historial de conversaciones se almacena en DynamoDB por sesión. El frontend (S3 + CloudFront) tiene un editor de código integrado.

**Complejidad adicional:** Implementar streaming de respuestas de Bedrock usando WebSockets en API Gateway.

- API Gateway debe tener configurado un **endpoint WebSocket** (no REST) para streaming de respuestas. La Lambda de conexión almacena el connectionId en DynamoDB con TTL de 1 hora. La Lambda que llama a Bedrock usa InvokeModelWithResponseStream y por cada chunk recibido hace un postToConnection al WebSocket para entregarlo al cliente en tiempo real.

- DynamoDB debe almacenar el **historial de conversación por sesión** (últimos 10 turnos). Cada invocación a Bedrock debe incluir el historial completo para mantener contexto. La Lambda debe calcular el número de tokens aproximado del historial y truncarlo si supera 6000 tokens, eliminando los turnos más antiguos primero.

- Cognito debe configurar un **Pre-Token Generation Lambda Trigger** que añada al JWT el atributo custom:dailyUsage (número de consultas del día). La Lambda Authorizer de API Gateway debe leer este claim y rechazar con 429 si el estudiante superó 50 consultas diarias, sin necesidad de consultar ninguna base de datos.

- S3 debe almacenar el código enviado y la respuesta de Bedrock como par en un objeto JSON, con el sub de Cognito como prefijo. Una Lambda con EventBridge Schedule semanal debe generar un reporte de uso por estudiante leyendo S3 con list_objects_v2 paginado.

---

### 7. Sistema de Inventario con Reabastecimiento Automático

**Servicios:** EC2 + ALB + RDS + Lambda + SQS + SNS + CloudWatch Events

**Descripción:** NGINX en EC2 sirve el frontend de inventario. RDS almacena stock. Un EventBridge Schedule activa Lambda cada hora para revisar niveles; si el stock cae por debajo del umbral, publica en SQS. Otra Lambda consume SQS, genera la orden de compra en RDS y notifica por SNS.

**Complejidad adicional:** Configurar RDS Proxy para gestionar el pool de conexiones desde múltiples Lambdas concurrentes.

- RDS debe usar **RDS Proxy** para gestionar el pool de conexiones. La Lambda debe conectarse exclusivamente vía el endpoint del Proxy, nunca directamente a RDS. Demostrar con CloudWatch las métricas de DatabaseConnections y QueryDuration con y sin Proxy bajo carga concurrente simulada.

- La Lambda de revisión de stock debe implementar **transacciones RDS** (usando START TRANSACTION / COMMIT / ROLLBACK): al crear una orden de reabastecimiento, debe decrementar el contador de "órdenes pendientes" y crear el registro de orden en una sola transacción atómica. Simular un fallo en mitad de la transacción y demostrar que los datos quedan consistentes.

- SQS debe tener configurado **long polling** (waitTimeSeconds: 20) y la Lambda consumidora debe usar **batch size 10** con reportBatchItemFailures habilitado, para que si falla procesar un item del batch, solo ese item vuelva a la cola y no los 10.

- CloudWatch Events (EventBridge) debe usar una **expresión cron personalizada** que ejecute la revisión solo en días hábiles (lunes a viernes) en horario de 8am-6pm. Fuera de ese horario, el sistema acepta órdenes pero las encola sin procesarlas.

---

### 8. Microservicios Bancarios con Event Sourcing

**Servicios:** API Gateway + Lambda + RDS (Aurora) + SQS + DynamoDB + CloudTrail

**Descripción:** Arquitectura de microservicios donde cada operación bancaria (transferencia, depósito, consulta) es un Lambda independiente. Cada transacción se registra como un evento inmutable en DynamoDB (event sourcing). SQS desacopla los servicios. CloudTrail audita todas las llamadas a APIs.

**Complejidad adicional:** Implementar transacciones distribuidas con el patrón Saga usando SQS para compensar fallos.

- Implementar el patrón **Saga Coreografada:** una transferencia entre cuentas genera eventos en SQS encadenados: DebitAccount → si exitoso publica AccountDebited → Lambda consume y ejecuta CreditAccount → si falla, consume CreditFailed y ejecuta RefundDebit como compensación. Cada paso debe quedar registrado como evento inmutable en DynamoDB.

- Aurora debe configurarse con **Aurora Serverless v2** con capacidad mínima 0.5 ACU y máxima 4 ACU. Demostrar con CloudWatch las métricas de ServerlessDatabaseCapacity durante una prueba de carga, y calcular el costo comparado con una instancia RDS convencional equivalente.

- Todas las Lambdas deben usar **X-Ray tracing activo** con anotaciones customizadas (transactionId, userId, operationType). El Service Map de X-Ray debe mostrar el flujo completo de una transferencia a través de todos los servicios. Identificar y documentar el subsegmento con mayor latencia.

- CloudTrail debe tener habilitado **Data Events para DynamoDB y S3** (no solo Management Events). Crear una CloudWatch Metric Filter sobre los logs de CloudTrail que detecte más de 5 operaciones DeleteItem en DynamoDB en 1 minuto y dispare una alarma SNS.

--- 

### 9. Sistema Zero-Trust de Gestión de Secretos para DevOps

**Servicios:** EC2 + ALB + Lambda + AWS Secrets Manager + IAM + CloudTrail + SNS

**Descripción:** Portal web donde equipos de desarrollo pueden solicitar credenciales temporales para ambientes de QA/producción. Lambda verifica el rol IAM del solicitante, recupera el secreto de Secrets Manager con rotación automática, y lo devuelve cifrado. CloudTrail registra cada acceso y SNS alerta ante accesos inusuales.

**Complejidad adicional:** Configurar rotación automática de secretos RDS con Lambda de rotación personalizada.

- IAM debe implementar **Permission Boundaries** en los roles de Lambda: aunque una Lambda tenga un rol con acceso amplio, el Permission Boundary limita el acceso máximo posible. Demostrar que incluso con políticas permisivas en el rol, el Permission Boundary impide acceder a secretos de producción desde Lambdas de desarrollo.

- Secrets Manager debe configurar **rotación automática cada 7 días** con una Lambda de rotación personalizada que: (1) crea el nuevo secreto en la BD, (2) actualiza Secrets Manager, (3) verifica que la nueva credencial funciona, (4) invalida la anterior. Si el paso 3 falla, debe hacer rollback automático.

- El ALB debe tener configuradas **reglas WAF** (AWS WAF asociado al ALB): bloquear IPs que hagan más de 100 requests/5 minutos, bloquear requests con patrones SQL injection en headers, y registrar todos los bloqueos en S3 via Kinesis Firehose.

- CloudTrail debe integrarse con **EventBridge Rules:** cuando CloudTrail registre un GetSecretValue desde una IP fuera del rango corporativo (simulado), EventBridge debe invocar una Lambda que deshabilite temporalmente el secreto y notifique por SNS con la IP, el usuario IAM y el timestamp del acceso.

---

### 10. Plataforma de Delivery con Seguimiento en Tiempo Real

**Servicios:** API Gateway (WebSocket) + Lambda + DynamoDB + S3 + SNS + EC2 + ALB

**Descripción:** API WebSocket en API Gateway permite al cliente ver la ubicación del repartidor en tiempo real. El repartidor (app móvil simulada) envía coordenadas GPS cada 5 segundos. Lambda actualiza DynamoDB y hace broadcast a todos los clientes conectados. Al completarse la entrega, SNS envía confirmación.

**Complejidad adicional:** Usar DynamoDB con índices GSI para consultas eficientes por zona geográfica.

- El WebSocket en API Gateway debe manejar **tres rutas custom:** $connect, $disconnect y location-update. La Lambda de location-update debe hacer broadcast solo a los clientes conectados que estén "siguiendo" esa orden específica, no a todos los conectados. DynamoDB debe tener una tabla de suscripciones {orderId, connectionId} con GSI para consultar por orderId.

- DynamoDB debe usar **conditional writes** en las actualizaciones de ubicación: solo aceptar la actualización si el timestamp del nuevo registro es mayor al último almacenado (evitar escrituras desordenadas). Si la condición falla, la Lambda debe descartar silenciosamente sin error.

- Al completarse una entrega, la Lambda debe ejecutar una **transacción DynamoDB** que en una sola operación atómica: actualice el estado de la orden a DELIVERED, cree un registro en la tabla de historial, e incremente el contador de entregas del repartidor. Si cualquiera de las tres falla, ninguna debe persistir.

- EC2 con NGINX debe servir el panel de operaciones con **rate limiting por IP** configurado en NGINX (limit_req_zone): máximo 10 requests/segundo por IP, con burst de 20. Demostrar el comportamiento con una prueba de carga y mostrar los logs de NGINX con los requests rechazados con 429.

---
 

### 11. Pipeline de Análisis de Datos Genómicos (Big Data Simulado)

**Servicios:** S3 + Lambda + AWS Glue + Athena + QuickSight + EC2

**Descripción:** Se suben archivos CSV grandes (datos de investigación simulados) a S3. Lambda activa un job de AWS Glue que limpia y transforma los datos. Athena permite consultas SQL directamente sobre S3. QuickSight genera visualizaciones. EC2 corre un Jupyter Notebook para análisis adicional.

**Complejidad adicional:** Implementar particionamiento de datos en S3 (por fecha/categoría) para optimizar costos de Athena.

- S3 debe usar una **estructura de particionamiento Hive** (/data/year=2025/month=04/day=15/) que Glue Crawler reconozca automáticamente. La Lambda que recibe los archivos debe renombrarlos y ubicarlos en la partición correcta según la fecha del contenido del archivo, no la fecha de carga.

- Glue debe tener **dos jobs encadenados** usando Glue Workflows: Job 1 limpia datos nulos y duplicados (PySpark), Job 2 agrega los datos por categoría y calcula estadísticas. El Workflow debe ser activado por Lambda vía start_workflow_run del SDK. Si Job 1 falla, Job 2 no debe ejecutarse.

- Athena debe configurar **workgroups separados** para estudiantes y profesores con límite de datos escaneados por query (estudiantes: 100MB, profesores: 1GB). Las queries deben guardarse en S3 con prefijo diferente por workgroup. Demostrar que una query que excede el límite es rechazada automáticamente.

- EC2 debe correr **JupyterHub** (multiusuario) con autenticación básica, donde múltiples estudiantes se conectan simultáneamente. NGINX actúa como reverse proxy con SSL terminado en NGINX. Demostrar que dos usuarios con notebooks simultáneos no interfieren entre sí.

---

### 12. Backend de Red Social Universitaria con Caché

**Servicios:** API Gateway + Lambda + RDS + ElastiCache (Redis) + S3 + CloudFront + Cognito

**Descripción:** Red social donde estudiantes publican posts con imágenes. ElastiCache (Redis) almacena el feed de publicaciones más recientes (evitando queries costosas a RDS). Las imágenes van a S3 + CloudFront. Cognito maneja autenticación OAuth con Google/Facebook universitario.

**Complejidad adicional:** Implementar el patrón Cache-Aside en Lambda: buscar en Redis primero, si no hay caché ir a RDS y poblar Redis.

- ElastiCache Redis debe implementar **tres estrategias de caché distintas** en la misma aplicación: Cache-Aside para perfiles de usuario (Lambda busca en Redis, si miss va a RDS y puebla Redis con TTL 10min), Write-Through para contadores de likes (Lambda escribe simultáneamente en Redis y RDS), y Cache Invalidation explícita cuando un usuario edita su perfil.

- RDS debe usar **índices compuestos** estratégicos: demostrar con EXPLAIN ANALYZE en PostgreSQL la diferencia de performance entre una query sin índice y con índice para el feed de publicaciones (ordenado por fecha, filtrado por lista de amigos). El índice debe diseñarse basado en el plan de ejecución real.

- Cognito debe tener configurado un **Post-Authentication Lambda Trigger** que actualice en RDS el campo last_login y registre la IP y el user agent. Si detecta un login desde un país diferente al habitual (comparando con los últimos 5 registros en RDS), debe enviar una alerta por SNS al email del usuario.

- CloudFront debe configurarse con **Lambda@Edge** en el evento viewer-request para: leer el JWT del cookie, decodificarlo (sin verificar firma, solo leer claims), y añadir un header X-User-Id al request antes de que llegue al origen. Esto evita que la Lambda de origen tenga que decodificar el token.

---

### 13. Sistema de CI/CD con Revisión Automática de Código

**8Servicios:** CodePipeline + CodeBuild + CodeDeploy + Lambda + S3 + SNS + EC2 + ALB

**Descripción:** Pipeline completo: el código se sube a S3 (o CodeCommit), CodePipeline orquesta las etapas, CodeBuild ejecuta pruebas unitarias, una Lambda invoca Amazon Bedrock para hacer revisión estática de código, CodeDeploy despliega en EC2 detrás del ALB con estrategia Blue/Green.

**Complejidad adicional:** Configurar deployment hooks en CodeDeploy para validar salud de la app antes de cambiar el tráfico en el ALB.

- CodeDeploy debe usar estrategia **Blue/Green** con el ALB haciendo el cambio de tráfico en tres fases: 10% al nuevo grupo por 5 minutos, 50% por 5 minutos más, 100% si las alarmas de CloudWatch no se disparan. Si en cualquier fase una alarma supera el umbral, CodeDeploy debe hacer rollback automático sin intervención humana.

- CodeBuild debe ejecutar **tres buildspecs en paralelo:** tests unitarios, análisis estático de seguridad con bandit (Python) o eslint-plugin-security, y construcción de la imagen Docker. Solo si los tres terminan exitosamente continúa el pipeline. Usar CodeBuild Batch Builds para la paralelización.

- La Lambda de revisión de código debe usar **Bedrock con prompt** estructurado que devuelva JSON con campos security_issues[], performance_issues[] y overall_score (0-100). Si overall_score < 60 o security_issues tiene elementos críticos, la Lambda debe marcar el stage de CodePipeline como fallido usando put_job_failure_result.

- S3 debe almacenar **todos los artefactos de cada ejecución** con versionamiento habilitado y una lifecycle policy que mueva artefactos de más de 30 días a S3 Glacier y los elimine a los 90 días. Demostrar que es posible redeployar cualquier versión anterior desde los artefactos almacenados.