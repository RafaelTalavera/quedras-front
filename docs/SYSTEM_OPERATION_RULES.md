# SYSTEM OPERATION RULES - COSTANORTE

## Regra geral de persistencia operacional
- Registros operacionais nao devem ser eliminados fisicamente pela aplicacao.
- Quando um item deixar de valer operacionalmente, o sistema deve cancelar ou inativar o registro.
- Cancelamentos exigem observacao que justifique a acao.
- O historico precisa continuar consultavel para auditoria e rastreabilidade.

## Regra geral de auditoria
- Toda criacao deve registrar quem executou a operacao e quando ela ocorreu.
- Toda edicao deve registrar o ultimo usuario responsavel e a data/hora da alteracao.
- Toda cancelacao deve registrar usuario, data/hora e observacao de cancelamento.
- A identificacao do usuario deve ser derivada da autenticacao JWT enviada pelo frontend ao backend.

## Aplicacao imediata no modulo de massagens
- Atendimentos nao devem ser removidos da base.
- O cancelamento do atendimento deve ser feito por endpoint dedicado e com observacao obrigatoria.
- Criacao, edicao e cancelamento do atendimento devem ficar auditados no backend.

## Verificacao recomendada no backend
- Confirmar que os endpoints autenticados persistem `createdBy`, `updatedBy`, `cancelledBy`, `createdAt`, `updatedAt` e `cancelledAt` quando aplicavel.
- Confirmar que nao existe endpoint `DELETE` para entidades operacionais de agenda.
- Confirmar que logs de auditoria e colunas de rastreio usam o usuario extraido do JWT, nao valores enviados livremente pelo cliente.

## Regra operacional para mudancas cross-repo
- Quando uma mudanca funcional alterar contrato entre frontend e backend, a execucao deve ocorrer nos dois repositorios na mesma iniciativa.
- O frontend nao pode assumir contrato novo sem confirmacao do backend real.
- O backend nao pode ser deixado como dependencia implícita se a UI nova depende dele para funcionar.
- Criterio minimo de fechamento para mudancas cross-repo:
  - endpoint implementado no backend
  - cliente/frontend alinhado ao contrato real
  - teste automatizado ou validacao manual ponta a ponta
  - documentacao atualizada com o status dos dois lados
