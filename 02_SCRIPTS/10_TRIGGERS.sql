-- script 10 - 3 triggers para auditoria, historico e bloqueio

use sistema_rh;

/* trigger 01 - registra no log qualquer alteracao de salario, armazenando o valor
anterior e o novo para auditoria e rastreabilidade das mudancas salariais. */
create trigger trg_auditoria_salario
on funcionario after update as
begin
    set nocount on;
    if update(salario)
    begin
        insert into log_funcionario (
            id_funcionario,
            campo_alterado,
            valor_anterior,
            valor_novo,
            operacao,
            data_operacao,
            usuario_bd
        )
        select
            i.id_funcionario,
            'salario',
            cast(d.salario as varchar(50)),
            cast(i.salario as varchar(50)),
            'U',
            getdate(),
            system_user
        from inserted i
        inner join deleted d on d.id_funcionario = i.id_funcionario
        where i.salario <> d.salario;
    end;
end;

-- testando a trigger de auditoria
update funcionario
set salario = 7000.00
where id_funcionario = 6;

-- verificando o log gerado
select * from log_funcionario order by data_operacao desc;

/* trigger 02 - registra no log todas as alteracoes de nome, departamento e cargo
dos funcionarios, identificando automaticamente se a operacao foi insercao,
atualizacao ou exclusao. */

create trigger trg_historico_funcionario
on funcionario
after insert, update, delete
as
begin
    set nocount on;

    declare @operacao char(1);

    if exists (select 1 from inserted) and exists (select 1 from deleted)
        set @operacao = 'U';
    else if exists (select 1 from inserted)
        set @operacao = 'I';
    else
        set @operacao = 'D';

    if @operacao in ('I', 'U')
    begin
        insert into log_funcionario (id_funcionario, campo_alterado, valor_anterior, valor_novo, operacao, data_operacao, usuario_bd)
        select
            i.id_funcionario,
            'nome_fun',
            isnull(d.nome_fun, 'novo registro'),
            i.nome_fun,
            @operacao,
            getdate(),
            system_user
        from inserted i
        left join deleted d on d.id_funcionario = i.id_funcionario
        where isnull(d.nome_fun, '') <> i.nome_fun;

        insert into log_funcionario (id_funcionario, campo_alterado, valor_anterior, valor_novo, operacao, data_operacao, usuario_bd)
        select
            i.id_funcionario,
            'id_departamento',
            cast(isnull(d.id_departamento, 0) as varchar(10)),
            cast(i.id_departamento as varchar(10)),
            @operacao,
            getdate(),
            system_user
        from inserted i
        left join deleted d on d.id_funcionario = i.id_funcionario
        where isnull(d.id_departamento, 0) <> i.id_departamento;

        insert into log_funcionario (id_funcionario, campo_alterado, valor_anterior, valor_novo, operacao, data_operacao, usuario_bd)
        select
            i.id_funcionario,
            'id_cargo',
            cast(isnull(d.id_cargo, 0) as varchar(10)),
            cast(i.id_cargo as varchar(10)),
            @operacao,
            getdate(),
            system_user
        from inserted i
        left join deleted d on d.id_funcionario = i.id_funcionario
        where isnull(d.id_cargo, 0) <> i.id_cargo;
    end;

    if @operacao = 'D'
    begin
        insert into log_funcionario (id_funcionario, campo_alterado, valor_anterior, valor_novo, operacao, data_operacao, usuario_bd)
        select
            d.id_funcionario,
            'registro_excluido',
            d.nome_fun,
            'excluido',
            'D',
            getdate(),
            system_user
        from deleted d;
    end;
end;

-- testando a trigger de historico (update de cargo)
update funcionario
set id_cargo = 1
where id_funcionario = 8;

-- verificando os logs gerados
select * from log_funcionario order by id_log desc;

/* trigger 03 - bloqueia a exclusao fisica de funcionarios com historico no sistema,
realizando em seu lugar a desativacao logica via data_demissao e registrando a
tentativa no log. funcionarios sem historico sao excluidos normalmente. */

create trigger trg_bloquear_exclusao_funcionario
on funcionario
instead of delete
as
begin
    set nocount on;

    declare @id_funcionario int;
    declare @tem_historico bit = 0;
    declare @nome_fun varchar(100);

    select @id_funcionario = id_funcionario,
           @nome_fun = nome_fun
    from deleted;

    if exists (select 1 from folha_pagamento where id_funcionario = @id_funcionario)
    or exists (select 1 from ponto where id_funcionario = @id_funcionario)
    or exists (select 1 from avaliacao_desempenho where id_funcionario = @id_funcionario)
    begin
        update funcionario
        set data_demissao = cast(getdate() as date)
        where id_funcionario = @id_funcionario;

        insert into log_funcionario (id_funcionario, campo_alterado, valor_anterior, valor_novo, operacao)
        values (
            @id_funcionario,
            'tentativa_exclusao_bloqueada',
            'ativo',
            'desativado_logicamente_pois_possui_historico',
            'U'
        );
        print 'aviso: funcionario "' + @nome_fun + '" possui historico no sistema. '
        + 'exclusao fisica bloqueada. funcionario desativado logicamente.';
    end
    else
    begin
        delete from funcionario
        where id_funcionario = @id_funcionario;

        print 'funcionario "' + @nome_fun + '" excluido com sucesso (sem historico relacionado).';
    end;
end;
go

-- testando a trigger instead of delete
delete from funcionario where id_funcionario = 6;

-- verifica que o funcionario nao foi excluido, apenas desativado
select id_funcionario, nome_fun, data_demissao from funcionario where id_funcionario = 6;

-- verificando todos os logs gerados ao longo dos testes
select
    id_log,
    id_funcionario,
    campo_alterado,
    valor_anterior,
    valor_novo,
    operacao,
    data_operacao,
    usuario_bd
from log_funcionario
order by id_log desc;