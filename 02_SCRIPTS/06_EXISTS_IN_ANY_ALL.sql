/* script 06 - exists / in / any / all com
5 exemplos comparando e demonstrando os operadores
exists, in, any e all no contexto do sistema de rh */

use sistema_rh;

/* exemplo 01 - lista os funcionarios que possuem ao menos um beneficio ativo,
demonstrando as duas formas equivalentes de fazer essa consulta: exists e in.*/

select
    f.id_funcionario,
    f.nome_fun,
    f.salario,
    d.nome_dep
from funcionario f
inner join departamento d on d.id_departamento = f.id_departamento
where exists (
    select 1
    from beneficio b
    where b.id_funcionario = f.id_funcionario
      and b.data_fim is null
)
and f.data_demissao is null
order by f.nome_fun;

/* exemplo 02 - lista os funcionarios ativos que ainda nao possuem nenhuma avaliacao
de desempenho registrada, ordenando pelos mais antigos na empresa. */

select
    f.id_funcionario,
    f.nome_fun,
    f.data_admissao,
    d.nome_dep,
    c.nome_cargo
from funcionario f
inner join departamento d on d.id_departamento = f.id_departamento
inner join cargo c on c.id_cargo = f.id_cargo
where not exists (
    select 1
    from avaliacao_desempenho av
    where av.id_funcionario = f.id_funcionario
)
and f.data_demissao is null
order by f.data_admissao;

/* exemplo 03 - lista os funcionarios de nivel senior e pleno, ordenando por nivel
e salario para facilitar analises de faixa salarial por senioridade. */

select
    f.nome_fun,
    f.salario,
    c.nome_cargo,
    c.nivel_cargo,
    d.nome_dep
from funcionario f
inner join cargo c on c.id_cargo = f.id_cargo
inner join departamento d on d.id_departamento = f.id_departamento
where c.nivel_cargo in ('Senior', 'Pleno')
  and f.data_demissao is null
order by c.nivel_cargo, f.salario desc;

/* exemplo 04 - lista os funcionarios nao juniores cujo salario supera ao menos
um salario da faixa junior, sendo util para verificar sobreposicao salarial
entre niveis.*/

select
    f.nome_fun,
    f.salario,
    c.nome_cargo,
    c.nivel_cargo
from funcionario f
inner join cargo c on c.id_cargo = f.id_cargo
where f.salario > any (
    select salario
    from funcionario f2
    inner join cargo c2 on c2.id_cargo = f2.id_cargo
    where c2.nivel_cargo = 'Junior'
      and f2.data_demissao is null
)
and c.nivel_cargo != 'Junior'
and f.data_demissao is null
order by f.salario desc;

/* exemplo 05 - lista os funcionarios cujo salario supera todos os salarios da faixa
junior, identificando quem esta completamente acima do teto dessa categoria. */

select
    f.nome_fun,
    f.salario,
    c.nome_cargo,
    c.nivel_cargo,
    d.nome_dep
from funcionario f
inner join cargo c on c.id_cargo = f.id_cargo
inner join departamento d on d.id_departamento = f.id_departamento
where f.salario > all (
    select salario
    from funcionario f2
    inner join cargo c2 on c2.id_cargo = f2.id_cargo
    where c2.nivel_cargo = 'Junior'
      and f2.data_demissao is null
)
and f.data_demissao is null
order by f.salario desc;