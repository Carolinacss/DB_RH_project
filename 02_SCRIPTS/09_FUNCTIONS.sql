/* script 09 - 2 functions para calculos automatizados no sistema de rh
dos tipos: scalar function e table-valued function */

use sistema_rh;

/* function 01 - calcula o salario liquido de um funcionario descontando inss, fgts
e beneficios ativos, retornando null caso o funcionario nao seja encontrado. */

create function fn_calcular_salario_liquido (
    @id_funcionario int
)
returns decimal(10,2)
as
begin
    declare @salario_bruto decimal(10,2);
    declare @desconto_inss decimal(10,2);
    declare @desconto_fgts decimal(10,2);
    declare @desconto_beneficios decimal(10,2);
    declare @salario_liquido decimal(10,2);

    select @salario_bruto = salario
    from funcionario
    where id_funcionario = @id_funcionario;

    if @salario_bruto is null
        return null;

    set @desconto_inss =
        case
            when @salario_bruto <= 1412.00 then @salario_bruto * 0.075
            when @salario_bruto <= 2666.68 then @salario_bruto * 0.09
            when @salario_bruto <= 4000.03 then @salario_bruto * 0.12
            when @salario_bruto <= 7786.02 then @salario_bruto * 0.14
            else 908.85
        end;

    set @desconto_fgts = @salario_bruto * 0.08;

    select @desconto_beneficios = isnull(sum(valor_mensal), 0)
    from beneficio
    where id_funcionario = @id_funcionario
      and data_fim is null;

    set @salario_liquido = @salario_bruto - @desconto_inss - @desconto_fgts - @desconto_beneficios;

    return @salario_liquido;
end;

-- testando a function scalar em uma consulta
select
    f.nome_fun,
    f.salario as salario_bruto,
    dbo.fn_calcular_salario_liquido(f.id_funcionario) as salario_liquido_calculado,
    f.salario - dbo.fn_calcular_salario_liquido(f.id_funcionario) as total_descontos
from funcionario f
where f.data_demissao is null
order by f.salario desc;

-- function 02 - retorna o relatorio de ponto de um funcionario em um periodo informado,
-- classificando cada dia como hora extra, dia normal, saida antecipada ou falta parcial.
create function fn_relatorio_ponto_funcionario (
    @id_funcionario int,
    @data_inicio date,
    @data_fim date
)
returns table
as
return (
    select
        p.data_ponto,
        p.horario_entrada,
        p.horario_saida_almoco,
        p.horario_retorno_almoco,
        p.horario_saida,
        p.horas_trabalhadas,
        case
            when p.horas_trabalhadas is null then 'sem registro'
            when p.horas_trabalhadas >= 9.0 then 'hora extra'
            when p.horas_trabalhadas >= 7.5 then 'dia normal'
            when p.horas_trabalhadas >= 6.0 then 'saida antecipada'
            else 'falta parcial'
        end as status_dia,
        case
            when p.horas_trabalhadas > 8.0 then p.horas_trabalhadas - 8.0
            else 0
        end as horas_extras_dia,
        f.nome_fun,
        d.nome_dep
    from ponto p
    inner join funcionario f on f.id_funcionario = p.id_funcionario
    inner join departamento d on d.id_departamento = f.id_departamento
    where p.id_funcionario = @id_funcionario
      and p.data_ponto between @data_inicio and @data_fim
);

-- testando a table-valued function
select
    data_ponto,
    horario_entrada,
    horario_saida,
    horas_trabalhadas,
    status_dia,
    horas_extras_dia
from dbo.fn_relatorio_ponto_funcionario(6, '2024-06-03', '2024-06-07')
order by data_ponto;

-- usando a tvf com join para calcular o valor monetario das horas extras de cada dia.
select
    rp.data_ponto,
    rp.nome_fun,
    rp.nome_dep,
    cast(rp.horas_trabalhadas as decimal(5,2)) as horas_trabalhadas,
    rp.status_dia,
    cast(round(rp.horas_extras_dia * (f.salario / 220.0) * 1.5, 2) as decimal (10,2)) as valor_hora_extra_r$
from dbo.fn_relatorio_ponto_funcionario(6, '2024-06-03', '2024-06-07') rp
inner join funcionario f on f.id_funcionario = 6
order by rp.data_ponto;