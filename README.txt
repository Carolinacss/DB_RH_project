<div align="center">
# 🗂️ Sistema de Recursos Humanos (Sistema RH)
 
**Estudo de caso — Banco de Dados**
 
<img src="https://img.shields.io/badge/SGBD-SQL%20Server%20Express%2016.0-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white" />
</div>
<br>
## 📖 Sobre o projeto
 
Este projeto é um sistema de gerenciamento de recursos humanos desenvolvido em **SQL Server**, criado como estudo de caso para a disciplina de Banco de Dados. Ele cobre o ciclo completo de gestão de RH: cadastro de funcionários, departamentos e cargos, controle de ponto, benefícios, avaliações de desempenho e folha de pagamento.
 
O grande foco do projeto é a **automação e a integridade dos dados diretamente no banco**: a folha de pagamento mensal é processada automaticamente, o histórico de alterações salariais é registrado sem intervenção manual, e regras de negócio são garantidas por meio de *triggers*, *procedures* e *functions* — não dependendo de validações externas na aplicação.
 
<br>
## 🚀 Recursos implementados
 
| Recurso | Detalhes | Script |
|---|---|---|
| ✅ Subconsultas | 10 exemplos | `04` |
| ✅ CTE | 5 exemplos | `05` |
| ✅ EXISTS | — | `06` |
| ✅ IN | — | `06` |
| ✅ ANY | — | `06` |
| ✅ ALL | — | `06` |
| ✅ VIEWs | 5 views | `07` |
| ✅ Procedures | 3 procedures | `08` |
| ✅ Functions | 2 functions | `09` |
| ✅ Triggers AFTER | — | `10` |
| ✅ Triggers INSTEAD OF | — | `10` |
 
<br>
## ▶️ Como executar
 
Os scripts devem ser executados **em ordem numérica**, já que cada um depende da estrutura criada pelo anterior:
 
```
01 · Sistema_RH          → criação do banco
02 · CREATE TABLES        → estrutura das tabelas
03 · INSERTS              → dados iniciais
04 · SUBCONSULTAS         → 10 exemplos de subconsultas
05 · CTE                  → 5 exemplos de CTE
06 · EXISTS_IN_ANY_ALL     → EXISTS, IN, ANY, ALL
07 · VIEWS                → 5 views
08 · PROCEDURES           → 3 stored procedures
09 · FUNCTIONS            → 2 functions
10 · TRIGGERS             → triggers AFTER e INSTEAD OF
```
 
<br>
## 👩‍💻 Autora
 
**Carolina de Oliveira Alves**
