-- script 08 - 3 stored procedures para automacao de processos do sistema de rh

use sistema_rh;

/* procedure 01 - processa a folha de pagamento mensal para todos os funcionarios ativos,
calculando horas extras, descontos de inss, fgts e beneficios para cada colaborador. */

create procedure sp_processar_folha_mensal
    @mes_referencia char(7)
as
begin
    set nocount on;
    declare @id_funcionario int;
    declare @salario_base decimal(10,2);
    declare @total_horas_extras decimal(5,2);
    declare @valor_hora_extra decimal(10,2);
    declare @desconto_inss decimal(10,2);
    declare @desconto_fgts decimal(10,2);
    declare @desconto_beneficios decimal(10,2);
    declare @qtd_funcionarios int = 0;

    declare cur_funcionarios cursor for
    select id_funcionario, salario
    from funcionario
    where data_demissao is null;

    begin try
        begin transaction;
        open cur_funcionarios;
        fetch next from cur_funcionarios into @id_funcionario, @salario_base;

        while @@fetch_status = 0
        begin
            select @total_horas_extras = isnull(sum(
                case when horas_trabalhadas > 8.0
                     then horas_trabalhadas - 8.0
                     else 0
                end), 0)
            from ponto
            where id_funcionario = @id_funcionario
            and format(data_ponto, 'yyyy-MM') = @mes_referencia;

            set @valor_hora_extra = (@salario_base / 220.0) * 1.5 * @total_horas_extras;

            set @desconto_inss =
                case
                    when @salario_base <= 1412.00 then @salario_base * 0.075
                    when @salario_base <= 2666.68 then @salario_base * 0.09
                    when @salario_base <= 4000.03 then @salario_base * 0.12
                    when @salario_base <= 7786.02 then @salario_base * 0.14
                    else 908.85
                end;

            set @desconto_fgts = @salario_base * 0.08;

            select @desconto_beneficios = isnull(sum(valor_mensal), 0)
            from beneficio
            where id_funcionario = @id_funcionario
              and data_fim is null;

            insert into folha_pagamento (
                salario_base, horas_extras,
                desconto_inss, desconto_beneficios, desconto_fgts,
                folha_criado_em, id_funcionario
            ) values (
                @salario_base,
                @valor_hora_extra,
                @desconto_inss,
                @desconto_beneficios,
                @desconto_fgts,
                getdate(),
                @id_funcionario
            );

            set @qtd_funcionarios = @qtd_funcionarios + 1;
            fetch next from cur_funcionarios into @id_funcionario, @salario_base;
        end;

        close cur_funcionarios;
        deallocate cur_funcionarios;

        commit transaction;
        print 'folha processada com sucesso para ' + cast(@qtd_funcionarios as varchar) + ' funcionarios.';

    end try
    begin catch
        if @@trancount > 0
            rollback transaction;

        if cursor_status('local', 'cur_funcionarios') >= 0
        begin
            close cur_funcionarios;
            deallocate cur_funcionarios;
        end;

        print 'erro ao processar folha: ' + error_message();
        throw;
    end catch;
end;

-- teste da procedure
exec sp_processar_folha_mensal
    @mes_referencia = '2023-06';

select * from folha_pagamento order by id_folha desc;

/* procedure 02 - registra as marcacoes de ponto do funcionario (entrada, saida para
almoco, retorno e saida), validando a sequencia correta das marcacoes do dia.*/
create procedure sp_registrar_ponto
    @id_funcionario int,
    @tipo_marcacao varchar(20),
    @horario time,
    @resultado varchar(200) output
as
begin
    set nocount on;
    declare @id_ponto_hoje int;
    declare @data_hoje date = cast(getdate() as date);
    if not exists (
        select 1 from funcionario
        where id_funcionario = @id_funcionario
          and data_demissao is null)
    begin
        set @resultado = 'erro: funcionario ' + cast(@id_funcionario as varchar) + ' nao encontrado ou inativo.';
        return;
    end;
    begin try
        begin transaction;
        select @id_ponto_hoje = id_ponto
        from ponto
        where id_funcionario = @id_funcionario
          and data_ponto = @data_hoje;
        if @id_ponto_hoje is null and @tipo_marcacao = 'entrada'
        begin
            insert into ponto (data_ponto, horario_entrada, horario_saida_almoco, horario_retorno_almoco, horario_saida, id_funcionario)
            values (@data_hoje, @horario, '00:00', '00:00', '00:00', @id_funcionario);
            set @resultado = 'entrada registrada com sucesso as ' + cast(@horario as varchar) + '.';
        end
        else if @id_ponto_hoje is not null
        begin
            if @tipo_marcacao = 'saida_almoco'
                update ponto set horario_saida_almoco = @horario where id_ponto = @id_ponto_hoje;
            else if @tipo_marcacao = 'retorno_almoco'
                update ponto set horario_retorno_almoco = @horario where id_ponto = @id_ponto_hoje;
            else if @tipo_marcacao = 'saida'
                update ponto set horario_saida = @horario where id_ponto = @id_ponto_hoje;
            else
            begin
                rollback transaction;
                set @resultado = 'erro: tipo de marcacao invalido.';
                return;
            end;
            set @resultado = @tipo_marcacao + ' registrada com sucesso as ' + cast(@horario as varchar) + '.';
        end
        else
        begin
            rollback transaction;
            set @resultado = 'erro: nenhuma entrada registrada hoje. registre a entrada primeiro.';
            return;
        end;
        commit transaction;
    end try
    begin catch
        if @@trancount > 0 rollback transaction;
        set @resultado = 'erro interno: ' + error_message();
        throw;
    end catch;
end;

/* procedure 03 - aplica reajuste salarial percentual a todos os funcionarios ativos
de um departamento, registrando o historico de alteracoes no log antes de atualizar. */
create procedure sp_reajuste_salarial
    @id_departamento int,
    @percentual decimal(5,2),
    @motivo varchar(100)
as
begin
    set nocount on;

    if @percentual <= 0 or @percentual > 50
    begin
        raiserror('percentual de reajuste deve ser entre 0 e 50.', 16, 1);
        return;
    end;

    if not exists (select 1 from departamento where id_departamento = @id_departamento)
    begin
        raiserror('departamento nao encontrado.', 16, 1);
        return;
    end;

    declare @qtd_reajustados int = 0;
    declare @nome_dep varchar(100);
    select @nome_dep = nome_dep from departamento where id_departamento = @id_departamento;

    begin try
        begin transaction;

        insert into log_funcionario (id_funcionario, campo_alterado, valor_anterior, valor_novo, operacao, data_operacao, usuario_bd)
        select
            id_funcionario,
            'salario',
            cast(salario as varchar(50)),
            cast(cast(round(salario * (1 + @percentual / 100.0),2) as decimal(10,2)) as varchar(50)),
            'U',
            getdate(),
            system_user
        from funcionario
        where id_departamento = @id_departamento
          and data_demissao is null;

        update funcionario
        set salario = round(salario * (1 + @percentual / 100.0), 2)
        where id_departamento = @id_departamento
          and data_demissao is null;

        set @qtd_reajustados = @@rowcount;

        commit transaction;
        print 'reajuste de ' + cast(@percentual as varchar) + '% aplicado a '
        + cast(@qtd_reajustados as varchar) + ' funcionarios do departamento ' + @nome_dep + '.';
        print 'motivo: ' + @motivo;

    end try
    begin catch
        if @@trancount > 0 rollback transaction;
        print 'erro ao aplicar reajuste: ' + error_message();
        throw;
    end catch;
end;

-- verificando salarios antes do reajuste
select id_funcionario, nome_fun, salario
from funcionario
where id_departamento = 1 and data_demissao is null;

-- aplicando reajuste de 10% no departamento 1
exec sp_reajuste_salarial
    @id_departamento = 1,
    @percentual = 10.00,
    @motivo = 'reajuste anual 2024';

-- verificando salarios apos o reajuste
select id_funcionario, nome_fun, salario
from funcionario
where id_departamento = 1 and data_demissao is null;

-- verificando o log gerado
select * from log_funcionario order by data_operacao desc;