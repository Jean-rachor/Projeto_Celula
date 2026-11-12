-- Sistema de Controle e Supervisao ESP32
-- PostgreSQL. Execute, por exemplo, com: psql -d NOME_DO_BANCO -f data/schema.sql
-- uid_hex preserva a representacao hexadecimal recebida (inclusive maiusculas e ':').
-- velocidade: passos por segundo; aceleracao: passos por segundo ao quadrado;
-- passos: passos do motor; angulo: graus; tempo_espera_ms: milissegundos.

BEGIN;

CREATE TABLE rfid_tags (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid_hex     VARCHAR(32) NOT NULL UNIQUE,
    descricao   TEXT,
    ativo       BOOLEAN NOT NULL DEFAULT TRUE,
    peca_id     BIGINT,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_rfid_uid_hex CHECK (uid_hex ~ '^[0-9A-Fa-f]{2}(:?[0-9A-Fa-f]{2})*$')
);

CREATE TABLE pecas (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo      VARCHAR(50) NOT NULL UNIQUE,
    nome        VARCHAR(150) NOT NULL,
    descricao   TEXT,
    tamanho     VARCHAR(80),
    cor         VARCHAR(80),
    material    VARCHAR(100),
    peso        NUMERIC(10,3),
    ativo       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_pecas_peso CHECK (peso IS NULL OR peso >= 0)
);

ALTER TABLE rfid_tags ADD CONSTRAINT fk_rfid_peca
    FOREIGN KEY (peca_id) REFERENCES pecas(id) ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX ix_rfid_tags_peca_id ON rfid_tags(peca_id);

CREATE TABLE ordens_producao (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_ordem            VARCHAR(50) NOT NULL UNIQUE,
    peca_id                 BIGINT NOT NULL REFERENCES pecas(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    quantidade_planejada    INTEGER NOT NULL,
    quantidade_produzida    INTEGER NOT NULL DEFAULT 0,
    status                  VARCHAR(20) NOT NULL DEFAULT 'PENDENTE',
    prioridade              SMALLINT NOT NULL DEFAULT 3,
    data_inicio             TIMESTAMP,
    data_previsao           TIMESTAMP,
    observacao              TEXT,
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_op_quantidades CHECK (quantidade_planejada > 0 AND quantidade_produzida >= 0 AND quantidade_produzida <= quantidade_planejada),
    CONSTRAINT ck_op_status CHECK (status IN ('PENDENTE','EM_EXECUCAO','CONCLUIDA','CANCELADA')),
    CONSTRAINT ck_op_prioridade CHECK (prioridade BETWEEN 1 AND 5),
    CONSTRAINT ck_op_datas CHECK (data_previsao IS NULL OR data_inicio IS NULL OR data_previsao >= data_inicio)
);
CREATE INDEX ix_ordens_producao_peca_id ON ordens_producao(peca_id);
CREATE INDEX ix_ordens_producao_status ON ordens_producao(status);

CREATE TABLE parametros_motor (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ordem_producao_id       BIGINT NOT NULL REFERENCES ordens_producao(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    passos                  INTEGER,
    direcao                 VARCHAR(15) NOT NULL,
    velocidade              NUMERIC(10,3) NOT NULL,
    aceleracao              NUMERIC(10,3),
    angulo                  NUMERIC(9,3),
    tempo_espera_ms         INTEGER NOT NULL DEFAULT 0,
    quantidade_movimentos   INTEGER NOT NULL DEFAULT 1,
    ativo                   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_motor_direcao CHECK (direcao IN ('HORARIO','ANTIHORARIO')),
    CONSTRAINT ck_motor_movimento CHECK ((passos IS NOT NULL AND passos > 0) OR (angulo IS NOT NULL AND angulo > 0)),
    CONSTRAINT ck_motor_velocidade CHECK (velocidade > 0),
    CONSTRAINT ck_motor_aceleracao CHECK (aceleracao IS NULL OR aceleracao > 0),
    CONSTRAINT ck_motor_espera CHECK (tempo_espera_ms >= 0),
    CONSTRAINT ck_motor_quantidade CHECK (quantidade_movimentos > 0)
);
CREATE INDEX ix_parametros_motor_ordem ON parametros_motor(ordem_producao_id);
CREATE UNIQUE INDEX ux_parametros_motor_ativo_por_ordem ON parametros_motor(ordem_producao_id) WHERE ativo;

CREATE TABLE dispositivos (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id       VARCHAR(80) NOT NULL UNIQUE,
    nome            VARCHAR(120) NOT NULL,
    mac_address     VARCHAR(17),
    ip_address      INET,
    localizacao     VARCHAR(150),
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    ultimo_status   VARCHAR(20),
    ultimo_contato  TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_dispositivo_status CHECK (ultimo_status IS NULL OR ultimo_status IN ('ONLINE','OFFLINE','ERRO')),
    CONSTRAINT ck_dispositivo_mac CHECK (mac_address IS NULL OR mac_address ~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$')
);

CREATE TABLE execucoes_producao (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ordem_producao_id       BIGINT NOT NULL REFERENCES ordens_producao(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    dispositivo_id          BIGINT NOT NULL REFERENCES dispositivos(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    inicio                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fim                     TIMESTAMP,
    status                  VARCHAR(15) NOT NULL DEFAULT 'AGUARDANDO',
    passos_executados       BIGINT NOT NULL DEFAULT 0,
    movimentos_executados   INTEGER NOT NULL DEFAULT 0,
    observacao              TEXT,
    CONSTRAINT ck_exec_status CHECK (status IN ('AGUARDANDO','EXECUTANDO','CONCLUIDA','ERRO','CANCELADA')),
    CONSTRAINT ck_exec_contadores CHECK (passos_executados >= 0 AND movimentos_executados >= 0),
    CONSTRAINT ck_exec_datas CHECK (fim IS NULL OR fim >= inicio)
);
CREATE INDEX ix_execucoes_ordem ON execucoes_producao(ordem_producao_id);
CREATE INDEX ix_execucoes_dispositivo ON execucoes_producao(dispositivo_id);

-- Dados ficticios para desenvolvimento. As IDs sao obtidas pelas chaves naturais.
INSERT INTO pecas (codigo, nome, descricao, tamanho, cor, material, peso) VALUES
('PEC-001','Carcaca W22','Peca demonstrativa para teste','Medio','Azul','Aluminio',2.500),
('PEC-002','Suporte S10','Peca demonstrativa para teste','Pequeno','Preto','Aco',1.200);

INSERT INTO rfid_tags (uid_hex, descricao, peca_id) VALUES
('A1B2C3D4','Tag ficticia da peca PEC-001',(SELECT id FROM pecas WHERE codigo='PEC-001')),
('04AABBCCDD','Tag ficticia da peca PEC-002',(SELECT id FROM pecas WHERE codigo='PEC-002'));

INSERT INTO ordens_producao (numero_ordem, peca_id, quantidade_planejada, quantidade_produzida, status, prioridade, data_inicio, data_previsao) VALUES
('OP-2026-00125',(SELECT id FROM pecas WHERE codigo='PEC-001'),100,45,'EM_EXECUCAO',2,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP + INTERVAL '2 days'),
('OP-2026-00126',(SELECT id FROM pecas WHERE codigo='PEC-002'),60,0,'PENDENTE',3,NULL,CURRENT_TIMESTAMP + INTERVAL '5 days');

INSERT INTO parametros_motor (ordem_producao_id, passos, direcao, velocidade, aceleracao, angulo, tempo_espera_ms, quantidade_movimentos) VALUES
((SELECT id FROM ordens_producao WHERE numero_ordem='OP-2026-00125'),200,'HORARIO',500,100,NULL,500,2),
((SELECT id FROM ordens_producao WHERE numero_ordem='OP-2026-00126'),160,'ANTIHORARIO',350,80,NULL,750,1);

INSERT INTO dispositivos (device_id, nome, localizacao, ativo, ultimo_status) VALUES
('ESP32-001','Controlador de demonstracao','Bancada de testes',TRUE,'OFFLINE');

-- Consulta simples: localizar a peca associada ao UID (parametro $1).
-- SELECT t.uid_hex, p.codigo, p.nome, p.tamanho, p.cor, p.material
-- FROM rfid_tags t JOIN pecas p ON p.id=t.peca_id
-- WHERE t.uid_hex=$1 AND t.ativo AND p.ativo;

-- Consulta para fornecer ao backend os dados de RFID, peca, ordem e motor ($1 = UID).
-- Seleciona ordens em andamento ou pendentes, priorizando a que esta em execucao.
-- SELECT jsonb_build_object(
--   'rfid', jsonb_build_object('uid_hex', t.uid_hex),
--   'ordem_producao', jsonb_build_object('numero', o.numero_ordem, 'status', o.status,
--     'quantidade_planejada', o.quantidade_planejada, 'quantidade_produzida', o.quantidade_produzida),
--   'peca', jsonb_build_object('codigo', p.codigo, 'nome', p.nome, 'tamanho', p.tamanho,
--     'cor', p.cor, 'material', p.material, 'peso', p.peso),
--   'motor', jsonb_build_object('passos', m.passos, 'direcao', m.direcao,
--     'velocidade', m.velocidade, 'aceleracao', m.aceleracao, 'angulo', m.angulo,
--     'tempo_espera_ms', m.tempo_espera_ms, 'quantidade_movimentos', m.quantidade_movimentos)
-- ) AS resposta
-- FROM rfid_tags t
-- JOIN pecas p ON p.id=t.peca_id
-- JOIN ordens_producao o ON o.peca_id=p.id
-- JOIN parametros_motor m ON m.ordem_producao_id=o.id AND m.ativo
-- WHERE t.uid_hex=$1 AND t.ativo AND p.ativo AND o.status IN ('PENDENTE','EM_EXECUCAO')
-- ORDER BY CASE o.status WHEN 'EM_EXECUCAO' THEN 0 ELSE 1 END, o.prioridade, o.created_at
-- LIMIT 1;

-- Exemplo de JSON retornado (valores ficticios; angulo fica null quando passos e usado):
-- {
--   "rfid": {"uid_hex":"A1B2C3D4"},
--   "ordem_producao": {"numero":"OP-2026-00125","status":"EM_EXECUCAO",
--     "quantidade_planejada":100,"quantidade_produzida":45},
--   "peca": {"codigo":"PEC-001","nome":"Carcaca W22","tamanho":"Medio",
--     "cor":"Azul","material":"Aluminio","peso":2.500},
--   "motor": {"passos":200,"direcao":"HORARIO","velocidade":500,
--     "aceleracao":100,"angulo":null,"tempo_espera_ms":500,"quantidade_movimentos":2}
-- }

COMMIT;

-- Relacionamentos:
-- rfid_tags N:1 pecas; pecas 1:N ordens_producao;
-- ordens_producao 1:N parametros_motor (uma configuracao ativa por ordem);
-- ordens_producao 1:N execucoes_producao; dispositivos 1:N execucoes_producao.
-- Fluxo: RFID -> peca -> ordem -> parametros do motor -> execucao em dispositivo ESP32.
