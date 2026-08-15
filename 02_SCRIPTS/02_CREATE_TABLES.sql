/* script 02 - criacao de todas as tabelas com chaves primárias, 
chaves estrangeiras, constraints e indices onde a 
ordem de criacao respeita as dependencias entre tabelas */

use sistema_rh;

/* A tabela departamento armazena os departamentos da empresa, onde
informa se o departamento está ativo com as letras 'S' = ativo, 'N' = inativo, a
data de criacao do departamento */

create table departamento (
    id_departamento int primary key identity(1,1),
    nome_dep varchar(100) not null,
    centro_de_custo varchar(20) not null,
    ativo_dep char(1) not null default 'S',
    data_dep datetime not null default getdate(),
    constraint ck_departamento_ativo check (ativo_dep in ('S', 'N'))
);

/* A tabela cargo armazena os todos cargos disponiveis na empresa cadastrados, 
onde o cargo_cbo é o codigo da classificacao brasileira de ocupacoes, o
nivel_cargo é o nivel hierarquico do cargo (junior, pleno, senior, etc) e as restrições colocadas de
ck_salario indica que o salario que for cadastrado não pode ultrapassar o valor máximo e ck_salario_posistivo o salário
não pode ser negativo.
*/

create table cargo (
    id_cargo int primary key identity(1,1),
    nome_cargo varchar(100) not null,
    centro_de_custo varchar(20) not null,
    nivel_cargo varchar(20) not null,
    cargo_salario_minimo decimal(10,2) not null,
    cargo_salario_maximo decimal(10,2) not null,
    cargo_cbo char(7) not null,

    constraint ck_cargo_salario check (cargo_salario_minimo <= cargo_salario_maximo),
    constraint ck_cargo_salario_positivo check (cargo_salario_minimo > 0 and cargo_salario_maximo > 0)
);

/* A tabela funcionario realiza o cadastro de todos os funcionarios da empresa
tanto funcionario comum e o gestor onde o id_gestor referencia para o funcionario gestor, o 
id_departamento e id_cargo são chaves estrangeiras que ligam as chaves primárias das outras tabelas do banco
e o genero é constituido por letras onde: 'M' = masculino, 'F' = feminino, 'O' = outro.
As restrições dessa tabela verificam se que o salario cadastrado do funcionário deve ser positivo;
o campo genero deve aceitar apenas as letras informadas;
a data de demissão não pode ser antes da data de admissão, sempre depois;
o funcionario gestor também é um funcionario.
*/

create table funcionario (
    id_funcionario int primary key identity(1,1),
    matricula varchar(10) not null unique,
    nome_fun varchar(100) not null,
    cpf char(11) not null unique,         
    data_nasc date not null,
    genero char(1) not null,
    email varchar(150) not null unique,         
    num_telefone varchar(20) not null,
    salario decimal(10,2) not null,
    data_admissao date not null,
    data_demissao date,                    
    id_gestor int,                    
    id_departamento int not null,
    id_cargo int not null,

    constraint ck_funcionario_genero check (genero in ('M', 'F', 'O')),
    constraint ck_funcionario_salario check (salario > 0),
    constraint ck_funcionario_datas check (data_demissao is null or data_demissao >= data_admissao),
    constraint fk_funcionario_gestor foreign key (id_gestor) references funcionario(id_funcionario),
    constraint fk_funcionario_departamento foreign key (id_departamento) references departamento(id_departamento),
    constraint fk_funcionario_cargo foreign key (id_cargo) references cargo(id_cargo)
);

/* A tabela ponto registra as marcacoes do dia do funcionario, onde verifica que
um ponto pertence a um funcionário, 
a entrada tem que ser antes do horário de saída, 
entrada do alomoço e saida do almoço dos funcionarios.
Registra também as horas_trabalhadas, onde a coluna calcula o desconto 
do intervalo de almoco com as horas trabalhadas. 
e a chave estrangeira id_funcionario está ligando essa tabela a tabela funcionario.
*/

create table ponto (
    id_ponto int primary key identity(1,1),
    data_ponto date not null,
    horario_entrada time not null,
    horario_saida_almoco time not null,
    horario_retorno_almoco time not null,
    horario_saida time not null,
    id_funcionario int not null,
    horas_trabalhadas as (
        case
            when horario_entrada is not null and horario_saida is not null
            then cast(
                    datediff(minute, horario_entrada, horario_saida)
                    - isnull(datediff(minute, horario_saida_almoco, horario_retorno_almoco), 0)
                 as decimal(5,2)) / 60.0
            else null
        end
    ),
    constraint ck_ponto_horarios check (horario_saida > horario_entrada),
    constraint fk_ponto_funcionario foreign key (id_funcionario) references funcionario(id_funcionario)
);

/* A tabela folha_pagamento registra a folha de pagamento mensal de cada funcionario
informando o salario_liquido que é calculada a partir do salario base com os descontos informados que não
podem ser negativos, e a chave estrangeira Id_funcionario liga a tabela a tabela Id_funcionario.
*/

create table folha_pagamento (
    id_folha int primary key identity(1,1),
    salario_base decimal(10,2) not null,
    horas_extras decimal(5,2) not null default 0,
    desconto_inss decimal(10,2) not null default 0,
    desconto_beneficios decimal(10,2) not null default 0,
    desconto_fgts decimal(10,2) not null default 0,
    folha_data_pagamento date,
    folha_criado_em datetime not null default getdate(),
    id_funcionario int not null,
    salario_liquido as (
        salario_base + horas_extras - desconto_beneficios - desconto_inss - desconto_fgts
    ),
    constraint ck_folha_descontos check (
        desconto_inss >= 0 and 
        desconto_beneficios >= 0 and 
        desconto_fgts >= 0
    ),
    constraint fk_folha_funcionario foreign key (id_funcionario) references funcionario(id_funcionario)
);

/* A tabela beneficio registra os beneficios vinculados a cada funcionario
informando o tipo de beneficio, o valor que deve ser positivo, data de inicio que deve ser informada 
obrigatoriamente e ser antes da data de fim, a chave estrangeira que liga essa tabela beneficio a tabela 
funcionario.
*/
create table beneficio (
    id_beneficio int primary key identity(1,1),
    tipo_beneficio varchar(50) not null,
    valor_mensal decimal(10,2) not null,
    data_inicio date not null,
    data_fim date,
    id_funcionario int not null,
    constraint ck_beneficio_valor check (valor_mensal > 0),
    constraint ck_beneficio_datas check (data_fim is null or data_fim >= data_inicio),
    constraint fk_beneficio_funcionario foreign key (id_funcionario) references funcionario(id_funcionario)
);

/* A tabela Avaliacao_desempenho registra as avaliacoes de desempenho dos funcionarios.
onde o id_avaliador é um funcionario da tabela funcionario que realizou a avaliacao e a 
nota final deve ser registrada entre 0.0 a 10.0. As chaves estrangeiras liga essa tabela a tabela
funcionario onde o avaliado e avaliador são ambos funcionarios.
*/

create table avaliacao_desempenho (
    id_avaliacao int primary key identity(1,1),
    id_funcionario int not null,
    id_avaliador int not null,
    periodo date not null,
    nota_final decimal(2,1) not null,
    constraint ck_avaliacao_nota check (nota_final >= 0.0 and nota_final <= 10.0),
    constraint fk_avaliacao_funcionario foreign key (id_funcionario) references funcionario(id_funcionario),
    constraint fk_avaliacao_avaliador   foreign key (id_avaliador)   references funcionario(id_funcionario)
);

/* A tabela log_funcionario (auditoria/historico)
registra todas as alterações feita na tabela funcionario, utilizando triggers
para rastrear mudancas nos dados dos funcionarios, informando os dados que foram
alterados, quem alterou e qual foi a operação utilizada pela modificação sendo 
informada pela primeira letra: 'I' = insert, 'U' = update, 'D' = delete
*/

create table log_funcionario (
    id_log int primary key identity(1,1),
    id_funcionario int not null,
    campo_alterado varchar(50) not null,
    valor_anterior varchar(255),
    valor_novo varchar(255),
    operacao char(1) not null,
    data_operacao datetime not null default getdate(),
    usuario_bd varchar(100) not null,
    constraint ck_log_operacao check (operacao in ('I', 'U', 'D'))
);

/*
Os indices são usados para melhorar a performance das consultas:
o primeiro faz a busca de funcionarios por departamento;
o segundo faz a busca de pontos por funcionario e a data do ponto;
e o terceiro faz a busca de folhas por funcionario.
*/

create index idx_funcionario_departamento
    on funcionario(id_departamento);
 
create index idx_ponto_funcionario_data
    on ponto(id_funcionario, data_ponto);

create index idx_folha_funcionario_status
    on folha_pagamento(id_funcionario);