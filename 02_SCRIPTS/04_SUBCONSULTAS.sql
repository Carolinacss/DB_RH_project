/* script 04 - subconsultas onde há 10 exemplos de subconsultas aplicadas ao sistema de rh
sendo simples, correlacionada, em select, em from, em where */

use sistema_rh;

/* subconsulta 01 - simples em where que lista os funcionarios que 
recebem acima da media salarial da empresa. A segunda subconsulta 
no select exibe a media ao lado de cada linha,permitindo 
visualizar a diferenca entre o salario do funcionario e a media geral, sendo
util para identificar colaboradores acima da media e analisar a
equidade salarial interna.
*/

select
    id_funcionario,
    nome_fun,
    salario,
    (select avg(salario) from funcionario) as media_geral
from funcionario
where salario > (
    select avg(salario)
    from funcionario
);

/* subconsulta 02 - exibe a media salarial e o total de funcionarios ativos
 por departamento, ordenando do mais caro ao mais barato, permitindo ao setor 
 financeiro visualizar o custo medio de pessoal por departamento para 
 apoiar decisoes de planejamento orcamentario.*/

select
    dep.nome_dep,
    medias.media_salario,
    medias.total_funcionarios
from (
    select
        f.id_departamento,
        avg(f.salario)          as media_salario,
        count(f.id_funcionario) as total_funcionarios
    from funcionario f
    where f.data_demissao is null
    group by f.id_departamento
) as medias
inner join departamento dep on dep.id_departamento = medias.id_departamento
order by medias.media_salario desc;

/* subconsulta 03 - encontra o funcionario com o maior salario dentro de cada
departamento, sendo que se dois funcionarios tiverem o mesmo salario maximo
ambos aparecerao no resultado.
*/
select
    f1.nome_fun,
    f1.salario,
    d.nome_dep
from funcionario f1
inner join departamento d on d.id_departamento = f1.id_departamento
where f1.salario = (
    select max(f2.salario)
    from funcionario f2
    where f2.id_departamento = f1.id_departamento
      and f2.data_demissao is null
)
and f1.data_demissao is null
order by f1.salario desc;

/* subconsulta 04 - lista os funcionarios que possuem ao menos uma avaliacao
de desempenho registrada no periodo 2023-12, facilitando o controle de quem
ainda precisa ser avaliado.
*/
select
    f.id_funcionario,
    f.nome_fun,
    f.salario,
    d.nome_dep,
    av.periodo
from funcionario f
inner join departamento d
    on d.id_departamento = f.id_departamento
inner join avaliacao_desempenho av
    on av.id_funcionario = f.id_funcionario
where av.periodo = '2023-12-01';

/* subconsulta 05 - exibe ao lado dos dados de cada funcionario a nota da sua
avaliacao de desempenho mais recente, retornando null caso nao possua nenhuma
avaliacao registrada. 
*/
select
    f.nome_fun,
    f.salario,
    c.nome_cargo,
    (
        select top 1 av.nota_final
        from avaliacao_desempenho av
        where av.id_funcionario = f.id_funcionario
        order by av.periodo desc
    ) as ultima_nota_avaliacao
from funcionario f
inner join cargo c on c.id_cargo = f.id_cargo
where f.data_demissao is null
order by f.nome_fun;

/* subconsulta 06 - lista os funcionarios que pertencem apenas aos departamentos
com mais de 3 colaboradores ativos, excluindo setores pequenos ou em fase
de estruturacao.
*/
select
    f.nome_fun,
    f.salario,
    d.nome_dep
from funcionario f
inner join departamento d on d.id_departamento = f.id_departamento
where f.id_departamento in (
    select id_departamento
    from funcionario
    where data_demissao is null
    group by id_departamento
    having count(id_funcionario) > 3
)
and f.data_demissao is null
order by d.nome_dep, f.nome_fun;

/* subconsulta 07 - lista os funcionarios cujo salario supera a media salarial
do departamento com maior folha total da empresa, onde procura o id_departamento 
com a maior soma de salarios usando top 1 com order by sum(salario) desc. Depois
usa o id retornado para calcular a media salarial especifica daquele departamento e por
fim filtra os funcionarios cujo salario supera essa media, independente do departamento. */

select
    f.nome_fun,
    f.salario,
    d.nome_dep
from funcionario f
inner join departamento d on d.id_departamento = f.id_departamento
where f.salario > (
    select avg(f2.salario)
    from funcionario f2
    where f2.id_departamento = (
        select top 1 id_departamento
        from funcionario
        where data_demissao is null
        group by id_departamento
        order by sum(salario) desc
    )
)
and f.data_demissao is null;

/* subconsulta 08 - identifica os funcionarios ativos que nao possuem
nenhum beneficio ativo cadastrado no sistema.
onde busca na lista de id_funcionario quem
possue ao menos um beneficio com data_fim null, ou seja ainda ativo, então
o not in exclui esses ids do resultado,
retornando apenas quem nao aparece nessa lista, para
regularizar o cadastro.*/

select
    f.id_funcionario,
    f.nome_fun,
    f.salario,
    d.nome_dep
from funcionario f
inner join departamento d on d.id_departamento = f.id_departamento
where f.id_funcionario not in (
    select distinct id_funcionario
    from beneficio
    where data_fim is null
)
and f.data_demissao is null
order by f.nome_fun;

/* subconsulta 09 - duas subconsultas escalares correlacionadas que
exibe para cada funcionario o total de avaliacoes realizadas e 
a media de todas as suas notas ao longo do tempo.
A primeira conta mostra quantas avaliacoes o funcionario possui no historico, 
a segunda calcula a media aritmetica de todas as notas registradas.
o order by media_notas desc coloca os melhores avaliados no topo,
permitindo uma visao rapida dos colaboradores de alto desempenho.
e incentivando conversas de feedback, promocoes e planos
de desenvolvimento individual com base no historico
de cada funcionario. */

select
    f.nome_fun,
    f.salario,
    c.nome_cargo,
    (
        select count(*)
        from avaliacao_desempenho av
        where av.id_funcionario = f.id_funcionario
    ) as total_avaliacoes,
    (
        select cast(avg(av.nota_final) as decimal(10, 1))
        from avaliacao_desempenho av
        where av.id_funcionario = f.id_funcionario
    ) as media_notas
from funcionario f
inner join cargo c on c.id_cargo = f.id_cargo
where f.data_demissao is null
order by media_notas desc;

/* subconsulta 10 - classifica cada funcionario dentro da faixa salarial
do seu cargo, calculando o percentual do salario em relacao ao teto do cargo
e aplicando um case para categorizar em tres faixas:
'inicio da faixa': salario proximo ao minimo do cargo (ate 20% acima)
'meio da faixa':   salario intermediario (ate 70% do maximo)
'topo da faixa':   salario proximo ou acima de 70% do teto do cargo
a consulta externa ordena pelo percentual_do_maximo de forma decrescente,
exibindo primeiro os funcionarios mais proximos do teto do cargo,podendo identificar 
quem esta proximo do teto e pode necessitar de promocao de cargo, e quem
ainda tem espaco de crescimento dentro da mesma faixa.
*/
select
    classificacao.nome_fun,
    classificacao.salario,
    classificacao.nome_cargo,
    classificacao.faixa_salarial,
    classificacao.percentual_do_maximo
from (
    select
        f.nome_fun,
        f.salario,
        c.nome_cargo,
        c.cargo_salario_minimo,
        c.cargo_salario_maximo,
        cast((f.salario / c.cargo_salario_maximo) * 100 as decimal(10,1)) as percentual_do_maximo,
        case
            when f.salario <= c.cargo_salario_minimo * 1.2 then 'inicio da faixa'
            when f.salario <= c.cargo_salario_maximo * 0.7 then 'meio da faixa' 
            else 'topo da faixa'
        end as faixa_salarial
    from funcionario f
    inner join cargo c on c.id_cargo = f.id_cargo
    where f.data_demissao is null
) as classificacao
order by classificacao.percentual_do_maximo desc;