# Deploy Specification

## Purpose

Orquestrar a stack completa do sistema RGM (PostgreSQL, MinIO, backend Spring
Boot, frontend servido via Nginx) para desenvolvimento local e para producao,
via Docker Compose e um Makefile de automacao — sem exigir Node/Java
instalados localmente para rodar em producao.

## Requirements

### Requirement: Setup inicial automatizado
O sistema SHALL prover um comando unico (`make setup`) que cria o arquivo
`.env` a partir do template (gerando um `JWT_SECRET` forte automaticamente) e
clona os repositorios irmaos `rgm-backend` e `rgm-frontend` como pastas
adjacentes.

#### Scenario: Primeira execucao
- **WHEN** `make setup` e executado em uma maquina sem `.env` nem os repos
  irmaos clonados
- **THEN** o `.env` e criado com `JWT_SECRET` preenchido, e os dois
  repositorios sao clonados alinhados a branch `main`

#### Scenario: Execucao repetida
- **WHEN** `make setup` e executado novamente com `.env` e os repos ja
  presentes
- **THEN** o comando nao sobrescreve o `.env` existente nem re-clona os repos

### Requirement: Producao via imagens pre-buildadas
O sistema SHALL permitir subir a stack de producao (`make prod-up`)
consumindo imagens Docker pre-construidas do GitHub Container Registry, sem
necessidade de compilar o codigo-fonte na maquina de destino.

#### Scenario: Subir stack de producao
- **WHEN** um operador com `.env` configurado executa `make prod-up`
- **THEN** os containers de PostgreSQL, MinIO, backend e frontend sobem
  usando as imagens do GHCR, sem build local

### Requirement: URL publica do MinIO obrigatoria em producao
O sistema SHALL exigir que `MINIO_PUBLIC_URL` aponte para um endereco
alcancavel pelo navegador do usuario final em producao — o valor padrao de
desenvolvimento nao deve ser mantido, sob risco dos links de evidencias/fotos
nao abrirem para quem usa o sistema.

#### Scenario: URL de producao configurada corretamente
- **WHEN** `MINIO_PUBLIC_URL` aponta para um dominio/IP publico acessivel
- **THEN** as evidencias e fotos anexadas ficam acessiveis pelos usuarios
  finais

#### Scenario: URL de desenvolvimento deixada em producao
- **WHEN** `MINIO_PUBLIC_URL` permanece com o valor padrao de
  desenvolvimento (nao roteavel externamente) em um deploy de producao
- **THEN** os links de evidencias/fotos ficam quebrados para os usuarios
  finais — este e um erro de configuracao a ser evitado, nao um estado
  suportado

### Requirement: Ambientes isolados por arquivo compose
O sistema SHALL manter tres arquivos docker-compose distintos e independentes
— desenvolvimento (`docker-compose.dev.yml`), infraestrutura auxiliar
(`docker-compose.infra.yml`) e producao (`docker-compose.prod.yml`) — cada um
com seu proprio conjunto de targets Makefile, sem misturar configuracao de
um ambiente com outro.

#### Scenario: Comando de dev nao afeta producao
- **WHEN** um operador roda `make up` (dev) em uma maquina que tambem roda a
  stack de producao
- **THEN** apenas os containers definidos em `docker-compose.dev.yml` sao
  afetados

### Requirement: Backup automatizado de Postgres e MinIO
O sistema SHALL manter, na stack de producao, backup automatico e agendado
do banco PostgreSQL (dump comprimido via `pg_dump`, com rotacao
diaria/semanal/mensal configuravel) e do bucket MinIO (espelhamento sem
remocao), gravados em bind mounts no host (`./backups/postgres`,
`./backups/minio`) para facilitar copia posterior para fora da VPS. O
sistema SHALL tambem permitir acionar um backup manual sob demanda via
`make backup-now`, sem esperar o proximo agendamento.

#### Scenario: Backup periodico do Postgres
- **WHEN** a stack de producao esta rodando
- **THEN** o servico `db-backup` executa `pg_dump` no horario configurado
  por `BACKUP_SCHEDULE` e mantem os arquivos conforme a retencao
  configurada (`BACKUP_KEEP_DAYS`/`BACKUP_KEEP_WEEKS`/`BACKUP_KEEP_MONTHS`)

#### Scenario: Backup periodico do MinIO sem propagar exclusoes
- **WHEN** a stack de producao esta rodando
- **THEN** o servico `minio-backup` espelha o bucket configurado para
  `./backups/minio` a cada `MINIO_BACKUP_INTERVAL_SECONDS`, sem remover do
  backup arquivos que foram apagados do bucket original

#### Scenario: Backup manual sob demanda
- **WHEN** um operador executa `make backup-now`
- **THEN** um backup do Postgres e um backup do MinIO sao executados
  imediatamente, fora do agendamento
