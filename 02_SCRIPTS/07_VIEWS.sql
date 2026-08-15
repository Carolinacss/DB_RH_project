-- script 07 - views 5 views criadas para o sistema de rh

use sistema_rh;

/* view 01 - exibe os dados publicos dos funcionarios ativos, ocultando informacoes
sensiveis como salario e cpf para consultas de uso geral. */
create view vw_funcionarios_publico as
    select
        id_funcionario,
        matricula,
        nome_fun,
        genero,
        email,
        num_telefone,
        data_admissao,
        id_departamento,
        id_cargo
    from funcionario
    where data_demissao is null;

select * from vw_funcionarios_publico order by nome_fun;

/* view 02 - consolida em uma unica consulta todos os dados cadastrais do funcionario,
incluindo departamento, cargo, faixa salarial do cargo, gestor e situacao atual. */
create view vw_funcionarios_completo as
    select
        f.id_funcionario,
        f.matricula,
        f.nome_fun,
        f.cpf,
        f.data_nasc,
        f.genero,
        f.email,
        f.num_telefone,
        f.salario,
        f.data_admissao,
        f.data_demissao,
        d.nome_dep,
        d.centro_de_custo,
        c.nome_cargo,
        c.nivel_cargo,
        c.cargo_salario_minimo,
        c.cargo_salario_maximo,
        g.nome_fun as nome_gestor,
        case when f.data_demissao is null then 'ativo' else 'inativo' end as situacao
    from funcionario f
    inner join departamento d on d.id_departamento = f.id_departamento
    inner join cargo c on c.id_cargo = f.id_cargo
    left join funcionario g on g.id_funcionario = f.id_gestor;

select
    nome_fun,
    nome_dep,
    nome_cargo,
    nivel_cargo,
    salario,
    situacao
from vw_funcionarios_completo
order by nome_dep, nome_fun;

/* view 03 - agrupa por departamento os principais indicadores de pessoal, como total
de funcionarios, folha salarial e media de avaliacao do ultimo periodo fechado. */
create view vw_indicadores_departamento as
    select
        d.id_departamento,
        d.nome_dep,
        d.ativo_dep,
        cast(count(f.id_funcionario) as decimal (10,2)) as total_funcionarios,
        sum(f.salario) as folha_salarial_total,
        cast(avg(f.salario) as decimal(10,2)) as media_salarial,
        min(f.salario) as menor_salario,
        max(f.salario) as maior_salario,
        cast(avg(av.nota_final) as decimal(10,2)) as media_avaliacao
    from departamento d
    left join funcionario f on f.id_departamento = d.id_departamento
                           and f.data_demissao is null
    left join avaliacao_desempenho av on av.id_funcionario = f.id_funcionario
                                     and av.periodo = '2023-12-01'
    group by
        d.id_departamento,
        d.nome_dep,
        d.ativo_dep;

select * from vw_indicadores_departamento;

/* view 04 - consolida os dados da folha de pagamento com o nome do funcionario,
departamento e cargo, facilitando a conferencia e o fechamento mensal. */

create view vw_folha_pagamento_consolidada as
    select
        f.id_funcionario,
        f.matricula,
        f.nome_fun,
        d.nome_dep,
        c.nome_cargo,
        fp.salario_base,
        fp.horas_extras,
        fp.desconto_inss,
        fp.desconto_fgts,
        fp.desconto_beneficios,
        fp.salario_liquido,
        fp.folha_data_pagamento,
        fp.folha_criado_em
    from folha_pagamento fp
    inner join funcionario f on f.id_funcionario = fp.id_funcionario
    inner join departamento d on d.id_departamento = f.id_departamento
    inner join cargo c on c.id_cargo = f.id_cargo;

-- testando a view de folha
select
    nome_fun,
    nome_dep,
    salario_base,
    salario_liquido
from vw_folha_pagamento_consolidada
order by salario_liquido desc;

/* view 05 - exibe as avaliacoes de desempenho com nome do funcionario, avaliador,
departamento e conceito calculado automaticamente a partir da nota final. */

create view vw_desempenho_funcionarios as
    select
        av.id_avaliacao,
        av.periodo,
        f.nome_fun,
        d.nome_dep,
        c.nome_cargo,
        av.nota_final,
        g.nome_fun as nome_avaliador,
        case
            when av.nota_final >= 9.0 then 'excelente'
            when av.nota_final >= 7.0 then 'bom'
            when av.nota_final >= 5.0 then 'regular'
            else 'abaixo do esperado'
        end as conceito
    from avaliacao_desempenho av
    inner join funcionario f on f.id_funcionario = av.id_funcionario
    inner join funcionario g on g.id_funcionario = av.id_avaliador
    inner join departamento d on d.id_departamento = f.id_departamento
    inner join cargo c on c.id_cargo = f.id_cargo;

select
    periodo,
    nome_fun,
    nome_dep,
    nota_final,
    conceito
from vw_desempenho_funcionarios
order by periodo desc, nota_final desc;

-- atualizando a view 01 para incluir o tempo de empresa em anos calculado dinamicamente.
alter view vw_funcionarios_publico as
    select
        id_funcionario,
        matricula,
        nome_fun,
        genero,
        email,
        num_telefone,
        data_admissao,
        datediff(year, data_admissao, getdate()) as anos_empresa,
        id_departamento,
        id_cargo
    from funcionario
    where data_demissao is null;
    select * from vw_funcionarios_publico;