# CROSS REPO CHANGE PROTOCOL

## Objetivo
- Evitar que mudancas que dependem de frontend e backend sejam fechadas apenas de um lado.

## Quando este protocolo e obrigatorio
- Sempre que o pedido envolver qualquer um destes itens:
  - endpoints
  - payloads
  - respostas JSON
  - entidades compartilhadas
  - persistencia
  - regras de negocio aplicadas no backend

## Sequencia obrigatoria
1. Identificar o repo frontend.
2. Identificar o repo backend.
3. Declarar explicitamente que o trabalho e `cross-repo`.
4. Implementar backend e frontend no mesmo fluxo.
5. Validar request e response reais.
6. Atualizar documentacao com:
   - o que foi feito no frontend
   - o que foi feito no backend
   - o que ainda falta

## Regra de no-cierre
- Se apenas um dos lados foi implementado, o cambio fica `incompleto`.
- Nao usar linguagem de fechamento como:
  - "implementado"
  - "listo"
  - "resuelto"
  sem deixar claro o estado dos dois repositorios.

## Aplicacao imediata
- Modulo `Massagens`
- Frontend: [quedras-front](/c:/Users/Public/Documents/Proyectos/quedras-front)
- Backend: [quadras](/c:/Users/Public/Documents/Proyectos/quadras)
