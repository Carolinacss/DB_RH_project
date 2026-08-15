/* script 05 - cte 5 exemplos de cte aplicadas ao sistema de rh */

use sistema_rh;

/* cte 01 - simples que lista os funcionarios com salario acima da media da empresa,
exibindo a diferenca e o percentual acima da media para analise de equidade salarial.*/

with media_salarial as (
    select avg(salario) as media
    from funcionario
    where data_demissao is null
)
select
    f.nome_fun,
    f.salario,
    cast(ms.media as decimal(10,2)) as media_empresa,
    cast(f.salario - ms.media as decimal(10,2)) as diferenca,
    cast(round((f.salario / ms.media - 1) * 10, 1) as decimal (4,1)) as percentual_acima_media
from funcionario f
cross join media_salarial ms
inner join cargo c on c.id_cargo = f.id_cargo
where f.salario > ms.media
  and f.data_demissao is null
order by f.salario desc;

/* cte 2 - multiplas ctes encadeadas que consolidam em uma unica consulta os dados
 de funcionarios ativos, suas medias de avaliacao e o total de beneficios mensais. */

with
funcionarios_ativos as (
    select
        f.id_funcionario,
        f.nome_fun,
        f.salario,
        f.id_departamento,
        f.id_cargo
    from funcionario f
    where f.data_demissao is null
),
medias_avaliacao as (
    select
        id_funcionario,
        avg(nota_final) as media_nota,
        count(*) as qtd_avaliacoes
    from avaliacao_desempenho
    group by id_funcionario
),
total_beneficios as (
    select
        id_funcionario,
        sum(valor_mensal) as total_mensal_beneficios,
        count(*) as qtd_beneficios
    from beneficio
    where data_fim is null
    group by id_funcionario
)
select
    d.nome_dep,
    fa.nome_fun,
    fa.salario,
    cast(isnull(ma.media_nota, 0.0) as decimal(10,2)) as media_avaliacao,
    isnull(ma.qtd_avaliacoes, 0) as total_avaliacoes,
    isnull(tb.total_mensal_beneficios, 0) as custo_beneficios,
    isnull(tb.qtd_beneficios, 0) as qtd_beneficios
from funcionarios_ativos fa
inner join departamento d on d.id_departamento = fa.id_departamento
left join medias_avaliacao ma on ma.id_funcionario = fa.id_funcionario
left join total_beneficios tb on tb.id_funcionario = fa.id_funcionario
order by d.nome_dep, fa.nome_fun;

/* cte 03 - calcula o custo total de rh por departamento somando salarios e beneficios
ativos, ordenando do mais caro ao mais barato para apoiar o planejamento orcamentario. */

with
custo_salarios as (
    select
        id_departamento,
        sum(salario) as total_salarios,
        count(*) as qtd_funcionarios,
        cast(round(avg(salario),2) as decimal(10,2)) as media_salario
    from funcionario
    where data_demissao is null
    group by id_departamento
),
custo_beneficios as (
    select
        f.id_departamento,
        sum(b.valor_mensal) as total_beneficios
    from beneficio b
    inner join funcionario f on f.id_funcionario = b.id_funcionario
    where b.data_fim is null
      and f.data_demissao is null
    group by f.id_departamento
)
select
    d.nome_dep,
    cs.qtd_funcionarios,
    cs.total_salarios,
    isnull(cb.total_beneficios, 0) as total_beneficios,
    cs.total_salarios + isnull(cb.total_beneficios, 0) as custo_total_rh,
    cs.media_salario
from custo_salarios cs
inner join departamento d on d.id_departamento = cs.id_departamento
left join custo_beneficios cb on cb.id_departamento = cs.id_departamento
order by custo_total_rh desc;

/* cte 04 - recursiva que monta a hierarquia de gestores da empresa exibindo o nivel
de cada funcionario na estrutura organizacional e o caminho completo ate a diretoria. */

with hierarquia_rh as (
    select
        f.id_funcionario,
        f.nome_fun,
        f.salario,
        f.id_gestor,
        0 as nivel,
        cast(f.nome_fun as varchar(500)) as caminho
    from funcionario f
    where f.id_gestor is null
      and f.data_demissao is null
    union all

    select
        f.id_funcionario,
        f.nome_fun,
        f.salario,
        f.id_gestor,
        h.nivel + 1,
        cast(h.caminho + ' > ' + f.nome_fun as varchar(500))
    from funcionario f
    inner join hierarquia_rh h on h.id_funcionario = f.id_gestor
    where f.data_demissao is null
)
select
    replicate(' ', nivel) + nome_fun as organograma,
    nivel,
    salario,
    caminho
from hierarquia_rh
order by caminho;

/* cte 05 - rankeia os funcionarios pela nota da avaliacao mais recente dentro de cada
departamento, retornando apenas os tres primeiros colocados por area. */

with avaliacoes_recentes as (
    select
        id_funcionario,
        nota_final,
        periodo,
        row_number() over (
            partition by id_funcionario
            order by periodo desc
        ) as rn
    from avaliacao_desempenho
),
ranking_departamento as (
    select
        f.id_funcionario,
        f.nome_fun,
        f.salario,
        f.id_departamento,
        ar.nota_final,
        ar.periodo,
        rank() over (
            partition by f.id_departamento
            order by ar.nota_final desc
        ) as posicao_no_dep
    from funcionario f
    inner join avaliacoes_recentes ar on 
    ar.id_funcionario = f.id_funcionario
    and ar.rn = 1
    where f.data_demissao is null
)
select
    d.nome_dep,
    rd.posicao_no_dep,
    rd.nome_fun,
    rd.nota_final,
    rd.salario,
    rd.periodo
from ranking_departamento rd
inner join departamento d on 
d.id_departamento = rd.id_departamento
where rd.posicao_no_dep <= 3
order by d.nome_dep, rd.posicao_no_dep;