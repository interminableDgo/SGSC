-- ============================================================
-- SGSC SALUD - BASE DE DATOS DESDE CERO
-- MySQL 8+
-- Version SIN VISTAS (sin vw_*)
--
-- Arquitectura prevista:
-- Flutter -> FastAPI -> MySQL
--
-- FastAPI realizará SELECT con JOIN sobre estas tablas.
--
-- ADVERTENCIA:
-- Las siguientes dos líneas BORRAN la BD anterior si existe.
-- Si tienes información que quieras conservar, respáldala primero.
-- ============================================================

DROP DATABASE IF EXISTS sgsc_salud;

CREATE DATABASE sgsc_salud
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE sgsc_salud;

-- ============================================================
-- 1. CATÁLOGOS GEOGRÁFICOS
-- ============================================================

CREATE TABLE cat_entidad_federativa (
    entidad_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave_inegi CHAR(2) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_entidad_clave (clave_inegi),
    UNIQUE KEY uq_entidad_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_region (
    region_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_region_clave (clave),
    UNIQUE KEY uq_region_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_municipio (
    municipio_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    entidad_id SMALLINT UNSIGNED NOT NULL,
    region_id SMALLINT UNSIGNED NULL,
    clave_inegi CHAR(3) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    CONSTRAINT fk_municipio_entidad
        FOREIGN KEY (entidad_id)
        REFERENCES cat_entidad_federativa(entidad_id),

    CONSTRAINT fk_municipio_region
        FOREIGN KEY (region_id)
        REFERENCES cat_region(region_id)
        ON DELETE SET NULL,

    UNIQUE KEY uq_municipio_inegi (entidad_id, clave_inegi),
    KEY idx_municipio_nombre (nombre),
    KEY idx_municipio_region (region_id)
) ENGINE=InnoDB;


CREATE TABLE cat_colonia (
    colonia_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    municipio_id INT UNSIGNED NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    codigo_postal VARCHAR(10) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    CONSTRAINT fk_colonia_municipio
        FOREIGN KEY (municipio_id)
        REFERENCES cat_municipio(municipio_id),

    KEY idx_colonia_municipio (municipio_id),
    KEY idx_colonia_nombre (nombre),
    KEY idx_colonia_cp (codigo_postal)
) ENGINE=InnoDB;


-- ============================================================
-- 2. CATÁLOGOS DEL BENEFICIARIO / SOLICITANTE
-- ============================================================

CREATE TABLE cat_sexo (
    sexo_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_sexo_clave (clave),
    UNIQUE KEY uq_sexo_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_con_quien_vive (
    con_quien_vive_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_con_quien_vive_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_seguridad_social (
    seguridad_social_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(40) NULL,
    nombre VARCHAR(120) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_seguridad_social_clave (clave),
    UNIQUE KEY uq_seguridad_social_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_grupo_vulnerable (
    grupo_vulnerable_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_grupo_vulnerable_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_tipo_discapacidad (
    tipo_discapacidad_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_tipo_discapacidad_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_parentesco (
    parentesco_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(40) NULL,
    nombre VARCHAR(100) NOT NULL,
    permite_otro TINYINT(1) NOT NULL DEFAULT 0,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_parentesco_clave (clave),
    UNIQUE KEY uq_parentesco_nombre (nombre)
) ENGINE=InnoDB;


-- ============================================================
-- 3. CATÁLOGOS DE LA SOLICITUD
-- ============================================================

CREATE TABLE cat_tipo_apoyo (
    tipo_apoyo_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_tipo_apoyo_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_estatus_solicitud (
    estatus_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    es_cerrado TINYINT(1) NOT NULL DEFAULT 0,
    es_resuelto TINYINT(1) NOT NULL DEFAULT 0,
    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_estatus_clave (clave),
    UNIQUE KEY uq_estatus_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_canal_recepcion (
    canal_recepcion_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(40) NULL,
    nombre VARCHAR(100) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_canal_clave (clave),
    UNIQUE KEY uq_canal_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_dependencia (
    dependencia_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(180) NOT NULL,
    siglas VARCHAR(30) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_dependencia_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_unidad_tratante (
    unidad_tratante_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dependencia_id INT UNSIGNED NULL,
    nombre VARCHAR(180) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    CONSTRAINT fk_unidad_dependencia
        FOREIGN KEY (dependencia_id)
        REFERENCES cat_dependencia(dependencia_id)
        ON DELETE SET NULL,

    UNIQUE KEY uq_unidad_nombre (nombre),
    KEY idx_unidad_dependencia (dependencia_id)
) ENGINE=InnoDB;


CREATE TABLE cat_partido_politico (
    partido_politico_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    siglas VARCHAR(30) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_partido_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_origen_envio (
    origen_envio_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    tipo VARCHAR(80) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_origen_envio_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE cat_prioridad (
    prioridad_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(30) NOT NULL,
    nombre VARCHAR(60) NOT NULL,
    sla_objetivo_dias SMALLINT UNSIGNED NOT NULL,
    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_prioridad_clave (clave),
    UNIQUE KEY uq_prioridad_nombre (nombre)
) ENGINE=InnoDB;


-- ============================================================
-- 4. USUARIOS Y ROLES
-- ============================================================

CREATE TABLE cat_rol (
    rol_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(40) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    UNIQUE KEY uq_rol_clave (clave),
    UNIQUE KEY uq_rol_nombre (nombre)
) ENGINE=InnoDB;


CREATE TABLE usuario (
    usuario_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombres VARCHAR(150) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    numero_empleado VARCHAR(30) NULL,
    puesto VARCHAR(120) NULL,
    correo VARCHAR(180) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    ultimo_acceso DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_usuario_correo (correo),
    UNIQUE KEY uq_usuario_numero_empleado (numero_empleado)
) ENGINE=InnoDB;


CREATE TABLE usuario_rol (
    usuario_id INT UNSIGNED NOT NULL,
    rol_id SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (usuario_id, rol_id),

    CONSTRAINT fk_usuario_rol_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_usuario_rol_rol
        FOREIGN KEY (rol_id)
        REFERENCES cat_rol(rol_id)
) ENGINE=InnoDB;


-- ============================================================
-- 5. BENEFICIARIO
-- ============================================================

CREATE TABLE beneficiario (
    beneficiario_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    nombres VARCHAR(150) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,

    curp VARCHAR(18) NULL,
    tiene_curp TINYINT(1) NOT NULL DEFAULT 0,

    fecha_nacimiento DATE NULL,
    sexo_id TINYINT UNSIGNED NULL,

    -- La entidad de nacimiento se obtiene del municipio.
    municipio_nacimiento_id INT UNSIGNED NULL,

    calle VARCHAR(150) NULL,
    numero VARCHAR(20) NULL,
    colonia_id INT UNSIGNED NULL,
    codigo_postal VARCHAR(10) NULL,

    -- La entidad de domicilio se obtiene del municipio.
    municipio_domicilio_id INT UNSIGNED NULL,

    -- La unidad (meses/años) debe definirse con el área funcional.
    tiempo_residencia INT UNSIGNED NULL,

    con_quien_vive_id SMALLINT UNSIGNED NULL,
    numero_hijos SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    cuenta_con_discapacidad TINYINT(1) NOT NULL DEFAULT 0,

    estudia_actualmente TINYINT(1) NOT NULL DEFAULT 0,
    area_estudio VARCHAR(150) NULL,
    profesion VARCHAR(150) NULL,
    fuente_ingresos VARCHAR(150) NULL,

    seguridad_social_id SMALLINT UNSIGNED NULL,
    numero_afiliacion VARCHAR(150) NULL,

    -- Campo conservado de la hoja original.
    emiso_tramite TINYINT(1) NULL,

    grupo_vulnerable_id SMALLINT UNSIGNED NULL,
    es_migrante TINYINT(1) NOT NULL DEFAULT 0,

    -- Campo conservado de la hoja original.
    codigo_2024 TINYINT(1) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_beneficiario_sexo
        FOREIGN KEY (sexo_id)
        REFERENCES cat_sexo(sexo_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_beneficiario_municipio_nacimiento
        FOREIGN KEY (municipio_nacimiento_id)
        REFERENCES cat_municipio(municipio_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_beneficiario_colonia
        FOREIGN KEY (colonia_id)
        REFERENCES cat_colonia(colonia_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_beneficiario_municipio_domicilio
        FOREIGN KEY (municipio_domicilio_id)
        REFERENCES cat_municipio(municipio_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_beneficiario_con_quien_vive
        FOREIGN KEY (con_quien_vive_id)
        REFERENCES cat_con_quien_vive(con_quien_vive_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_beneficiario_seguridad_social
        FOREIGN KEY (seguridad_social_id)
        REFERENCES cat_seguridad_social(seguridad_social_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_beneficiario_grupo_vulnerable
        FOREIGN KEY (grupo_vulnerable_id)
        REFERENCES cat_grupo_vulnerable(grupo_vulnerable_id)
        ON DELETE SET NULL,

    UNIQUE KEY uq_beneficiario_curp (curp),

    KEY idx_beneficiario_nombre (apellidos, nombres),
    KEY idx_beneficiario_fecha_nacimiento (fecha_nacimiento),
    KEY idx_beneficiario_municipio_domicilio (municipio_domicilio_id),
    KEY idx_beneficiario_grupo_vulnerable (grupo_vulnerable_id)
) ENGINE=InnoDB;


CREATE TABLE beneficiario_telefono (
    beneficiario_telefono_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    beneficiario_id INT UNSIGNED NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    tipo VARCHAR(30) NULL,
    es_principal TINYINT(1) NOT NULL DEFAULT 0,

    CONSTRAINT fk_beneficiario_telefono
        FOREIGN KEY (beneficiario_id)
        REFERENCES beneficiario(beneficiario_id)
        ON DELETE CASCADE,

    UNIQUE KEY uq_beneficiario_telefono (beneficiario_id, telefono),
    KEY idx_telefono_numero (telefono)
) ENGINE=InnoDB;


CREATE TABLE beneficiario_discapacidad (
    beneficiario_id INT UNSIGNED NOT NULL,
    tipo_discapacidad_id SMALLINT UNSIGNED NOT NULL,
    observaciones VARCHAR(255) NULL,

    PRIMARY KEY (beneficiario_id, tipo_discapacidad_id),

    CONSTRAINT fk_beneficiario_discapacidad_beneficiario
        FOREIGN KEY (beneficiario_id)
        REFERENCES beneficiario(beneficiario_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_beneficiario_discapacidad_tipo
        FOREIGN KEY (tipo_discapacidad_id)
        REFERENCES cat_tipo_discapacidad(tipo_discapacidad_id)
) ENGINE=InnoDB;


-- ============================================================
-- 6. SOLICITANTE
-- ============================================================

CREATE TABLE solicitante (
    solicitante_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,

    parentesco_id SMALLINT UNSIGNED NULL,
    otro_parentesco VARCHAR(100) NULL,

    fecha_nacimiento DATE NULL,

    calle VARCHAR(150) NULL,
    numero VARCHAR(20) NULL,

    colonia_id INT UNSIGNED NULL,
    colonia_otro VARCHAR(150) NULL,

    codigo_postal VARCHAR(10) NULL,

    -- El estado se obtiene por medio de municipio -> entidad.
    municipio_id INT UNSIGNED NULL,

    telefono VARCHAR(20) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_solicitante_parentesco
        FOREIGN KEY (parentesco_id)
        REFERENCES cat_parentesco(parentesco_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitante_colonia
        FOREIGN KEY (colonia_id)
        REFERENCES cat_colonia(colonia_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitante_municipio
        FOREIGN KEY (municipio_id)
        REFERENCES cat_municipio(municipio_id)
        ON DELETE SET NULL,

    KEY idx_solicitante_nombre (apellidos, nombres),
    KEY idx_solicitante_municipio (municipio_id),
    KEY idx_solicitante_telefono (telefono)
) ENGINE=InnoDB;


-- ============================================================
-- 7. SOLICITUD DE APOYO
-- ============================================================

CREATE TABLE solicitud_apoyo (
    solicitud_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- FastAPI genera este folio.
    -- Ejemplo: SGSC-2026-000001
    folio VARCHAR(30) NOT NULL,

    -- FK: NO se guarda el nombre del beneficiario aquí.
    beneficiario_id INT UNSIGNED NOT NULL,

    -- Puede ser NULL si quien solicita es el mismo beneficiario.
    solicitante_id INT UNSIGNED NULL,

    -- Corresponde a "Enviado por ID".
    enviado_por_id INT UNSIGNED NULL,

    dependencia_id INT UNSIGNED NULL,
    partido_politico_id SMALLINT UNSIGNED NULL,

    -- Municipio y colonia asociados a la solicitud.
    municipio_id INT UNSIGNED NULL,
    colonia_id INT UNSIGNED NULL,

    detalles_enviado_por VARCHAR(150) NULL,

    tipo_apoyo_id INT UNSIGNED NOT NULL,

    descripcion TEXT NOT NULL,
    observaciones TEXT NULL,

    -- Una solicitud puede referenciar otra.
    referencia_id INT UNSIGNED NULL,

    responsable_usuario_id INT UNSIGNED NULL,

    estatus_id SMALLINT UNSIGNED NOT NULL,
    canal_recepcion_id SMALLINT UNSIGNED NULL,
    unidad_tratante_id INT UNSIGNED NULL,

    prioridad_id SMALLINT UNSIGNED NOT NULL,

    -- Para el KPI de riesgo inmediato.
    riesgo_inmediato TINYINT(1) NOT NULL DEFAULT 0,

    fecha_recepcion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_evaluacion DATETIME NULL,
    fecha_cierre DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_solicitud_beneficiario
        FOREIGN KEY (beneficiario_id)
        REFERENCES beneficiario(beneficiario_id),

    CONSTRAINT fk_solicitud_solicitante
        FOREIGN KEY (solicitante_id)
        REFERENCES solicitante(solicitante_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_enviado_por
        FOREIGN KEY (enviado_por_id)
        REFERENCES cat_origen_envio(origen_envio_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_dependencia
        FOREIGN KEY (dependencia_id)
        REFERENCES cat_dependencia(dependencia_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_partido
        FOREIGN KEY (partido_politico_id)
        REFERENCES cat_partido_politico(partido_politico_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_municipio
        FOREIGN KEY (municipio_id)
        REFERENCES cat_municipio(municipio_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_colonia
        FOREIGN KEY (colonia_id)
        REFERENCES cat_colonia(colonia_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_tipo_apoyo
        FOREIGN KEY (tipo_apoyo_id)
        REFERENCES cat_tipo_apoyo(tipo_apoyo_id),

    CONSTRAINT fk_solicitud_referencia
        FOREIGN KEY (referencia_id)
        REFERENCES solicitud_apoyo(solicitud_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_responsable
        FOREIGN KEY (responsable_usuario_id)
        REFERENCES usuario(usuario_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_estatus
        FOREIGN KEY (estatus_id)
        REFERENCES cat_estatus_solicitud(estatus_id),

    CONSTRAINT fk_solicitud_canal
        FOREIGN KEY (canal_recepcion_id)
        REFERENCES cat_canal_recepcion(canal_recepcion_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_unidad
        FOREIGN KEY (unidad_tratante_id)
        REFERENCES cat_unidad_tratante(unidad_tratante_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_solicitud_prioridad
        FOREIGN KEY (prioridad_id)
        REFERENCES cat_prioridad(prioridad_id),

    UNIQUE KEY uq_solicitud_folio (folio),

    KEY idx_solicitud_fecha (fecha_recepcion),
    KEY idx_solicitud_beneficiario (beneficiario_id),
    KEY idx_solicitud_solicitante (solicitante_id),
    KEY idx_solicitud_municipio (municipio_id),
    KEY idx_solicitud_colonia (colonia_id),
    KEY idx_solicitud_tipo_apoyo (tipo_apoyo_id),
    KEY idx_solicitud_dependencia (dependencia_id),
    KEY idx_solicitud_estatus (estatus_id),
    KEY idx_solicitud_prioridad (prioridad_id),
    KEY idx_solicitud_riesgo (riesgo_inmediato),
    KEY idx_solicitud_responsable (responsable_usuario_id)
) ENGINE=InnoDB;


-- ============================================================
-- 8. HISTORIAL DE ESTATUS
-- ============================================================

CREATE TABLE solicitud_estatus_historial (
    historial_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    solicitud_id INT UNSIGNED NOT NULL,
    estatus_id SMALLINT UNSIGNED NOT NULL,
    usuario_id INT UNSIGNED NULL,
    comentario VARCHAR(500) NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_historial_solicitud
        FOREIGN KEY (solicitud_id)
        REFERENCES solicitud_apoyo(solicitud_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_historial_estatus
        FOREIGN KEY (estatus_id)
        REFERENCES cat_estatus_solicitud(estatus_id),

    CONSTRAINT fk_historial_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON DELETE SET NULL,

    KEY idx_historial_solicitud_fecha (solicitud_id, fecha_cambio),
    KEY idx_historial_estatus (estatus_id)
) ENGINE=InnoDB;


-- ============================================================
-- 9. EVIDENCIAS / ARCHIVOS DE LA SOLICITUD
-- ============================================================

CREATE TABLE solicitud_evidencia (
    evidencia_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    solicitud_id INT UNSIGNED NOT NULL,
    nombre_archivo VARCHAR(255) NOT NULL,
    ruta_archivo VARCHAR(500) NOT NULL,
    tipo_mime VARCHAR(100) NULL,
    descripcion VARCHAR(255) NULL,
    subido_por_usuario_id INT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_evidencia_solicitud
        FOREIGN KEY (solicitud_id)
        REFERENCES solicitud_apoyo(solicitud_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_evidencia_usuario
        FOREIGN KEY (subido_por_usuario_id)
        REFERENCES usuario(usuario_id)
        ON DELETE SET NULL,

    KEY idx_evidencia_solicitud (solicitud_id)
) ENGINE=InnoDB;


-- ============================================================
-- 10. DATOS INICIALES DE CATÁLOGOS
-- ============================================================

INSERT INTO cat_sexo (clave, nombre) VALUES
('HOMBRE', 'Hombre'),
('MUJER', 'Mujer'),
('NO_ESPECIFICADO', 'No especificado');


INSERT INTO cat_parentesco (clave, nombre, permite_otro) VALUES
('MISMO_BENEFICIARIO', 'Mismo beneficiario', 0),
('MADRE', 'Madre', 0),
('PADRE', 'Padre', 0),
('HIJO_HIJA', 'Hijo(a)', 0),
('CONYUGE_PAREJA', 'Cónyuge / Pareja', 0),
('HERMANO_HERMANA', 'Hermano(a)', 0),
('OTRO', 'Otro', 1);


INSERT INTO cat_estatus_solicitud
(clave, nombre, es_cerrado, es_resuelto, orden_visual) VALUES
('RECIBIDA', 'Recibida', 0, 0, 10),
('EN_EVALUACION', 'En evaluación', 0, 0, 20),
('ASIGNADA', 'Asignada', 0, 0, 30),
('EN_ATENCION', 'En atención', 0, 0, 40),
('RESUELTA', 'Resuelta', 1, 1, 50),
('RESUELTA_OBS', 'Resuelta con observaciones', 1, 1, 55),
('NO_COMPETENCIA', 'No competencia', 1, 0, 60),
('CANCELADA', 'Cancelada', 1, 0, 70);


INSERT INTO cat_prioridad
(clave, nombre, sla_objetivo_dias, orden_visual) VALUES
('CRITICA', 'Crítica', 3, 10),
('ALTA', 'Alta', 7, 20),
('MEDIA', 'Media', 15, 30),
('BAJA', 'Baja', 30, 40);


INSERT INTO cat_canal_recepcion (clave, nombre) VALUES
('APP_EJECUTIVA', 'App Ejecutiva'),
('PORTAL_WEB', 'Portal web'),
('PRESENCIAL', 'Presencial'),
('TELEFONO', 'Teléfono'),
('CORREO', 'Correo electrónico'),
('WHATSAPP', 'WhatsApp'),
('CALL_CENTER', 'Call center'),
('REDES_SOCIALES', 'Redes sociales'),
('MENSAJERIA', 'Mensajería'),
('OFICIO', 'Oficio');


INSERT INTO cat_rol (clave, nombre) VALUES
('EJECUTIVO', 'Ejecutivo'),
('OPERATIVO', 'Operativo'),
('ADMINISTRADOR', 'Administrador');


INSERT INTO cat_region (clave, nombre) VALUES
('METROPOLITANA', 'Metropolitana'),
('PERIFERICA', 'Periférica'),
('CITRICA', 'Cítrica'),
('NORTE', 'Norte'),
('SUR', 'Sur');


INSERT INTO cat_grupo_vulnerable (nombre, descripcion) VALUES
('Adulto mayor', 'Categoría para análisis ejecutivo'),
('Persona con discapacidad', 'Categoría para análisis ejecutivo'),
('Enfermedad crónica', 'Categoría para análisis ejecutivo'),
('Niñez y adolescencia', 'Categoría para análisis ejecutivo'),
('Mujer embarazada', 'Categoría para análisis ejecutivo'),
('Situación de calle', 'Categoría para análisis ejecutivo'),
('Población general', 'Categoría general');


-- ============================================================
-- 11. NUEVO LEÓN + MUNICIPIOS UTILIZADOS POR EL PROTOTIPO
-- ============================================================

INSERT INTO cat_entidad_federativa (clave_inegi, nombre)
VALUES ('19', 'Nuevo León');


-- Insertamos municipios de prueba / prototipo y les asociamos región.
INSERT INTO cat_municipio
(entidad_id, region_id, clave_inegi, nombre)
SELECT
    e.entidad_id,
    r.region_id,
    x.clave_inegi,
    x.nombre
FROM cat_entidad_federativa e
CROSS JOIN cat_region r
JOIN (
    SELECT '039' AS clave_inegi, 'Monterrey' AS nombre, 'METROPOLITANA' AS region_clave
    UNION ALL SELECT '026', 'Guadalupe', 'METROPOLITANA'
    UNION ALL SELECT '006', 'Apodaca', 'METROPOLITANA'
    UNION ALL SELECT '021', 'General Escobedo', 'METROPOLITANA'
    UNION ALL SELECT '046', 'San Nicolás de los Garza', 'METROPOLITANA'
    UNION ALL SELECT '048', 'Santa Catarina', 'METROPOLITANA'
    UNION ALL SELECT '018', 'García', 'METROPOLITANA'
    UNION ALL SELECT '031', 'Juárez', 'METROPOLITANA'
    UNION ALL SELECT '019', 'San Pedro Garza García', 'METROPOLITANA'
    UNION ALL SELECT '009', 'Cadereyta Jiménez', 'PERIFERICA'
    UNION ALL SELECT '038', 'Montemorelos', 'CITRICA'
    UNION ALL SELECT '004', 'Allende', 'CITRICA'
    UNION ALL SELECT '044', 'Sabinas Hidalgo', 'NORTE'
    UNION ALL SELECT '049', 'Santiago', 'SUR'
    UNION ALL SELECT '033', 'Linares', 'SUR'
) x
    ON x.region_clave = r.clave
WHERE e.clave_inegi = '19';


-- ============================================================
-- 12. CONSULTAS DE VERIFICACIÓN
-- ============================================================

SHOW TABLES;

SELECT DATABASE() AS base_actual;

SELECT COUNT(*) AS total_estatus
FROM cat_estatus_solicitud;

SELECT COUNT(*) AS total_prioridades
FROM cat_prioridad;

SELECT COUNT(*) AS total_municipios_iniciales
FROM cat_municipio;


-- ============================================================
-- 13. EJEMPLO DE CÓMO SE RELACIONAN LOS DATOS
-- ============================================================
--
-- En solicitud_apoyo NO se guarda:
--     beneficiario = 'María González'
--
-- Se guarda:
--     beneficiario_id = 15
--
-- Y FastAPI obtiene el nombre usando JOIN:
--
-- SELECT
--     sa.solicitud_id,
--     sa.folio,
--     b.nombres,
--     b.apellidos
-- FROM solicitud_apoyo sa
-- INNER JOIN beneficiario b
--     ON b.beneficiario_id = sa.beneficiario_id;
--
-- Lo mismo ocurre con:
-- solicitante_id
-- municipio_id
-- colonia_id
-- tipo_apoyo_id
-- dependencia_id
-- prioridad_id
-- estatus_id
-- canal_recepcion_id
-- responsable_usuario_id
--
-- ============================================================
-- FIN
-- ============================================================
