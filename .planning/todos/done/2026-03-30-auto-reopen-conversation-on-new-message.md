---
created: 2026-03-30T15:05:11.530Z
title: Auto-reopen or notify when client messages a pending kanban card
area: general
files: []
---

## Problem

Quando um cliente envia mensagem e o card com a conversa atrelada está em status "pendente" no kanban, o agente pode não perceber. A configuração do kanban deveria permitir: reabrir a conversa automaticamente e mover para outra coluna, ou exibir um indicador visual no card de que há mensagem nova para responder.

## Solution

Avaliar melhor abordagem:
1. **Auto-mover**: ao receber mensagem nova em conversa pendente, mover card para coluna configurada (ex: "aberto") — mais agressivo, pode ser indesejado.
2. **Indicador visual**: adicionar badge/indicador no card mostrando que tem mensagem pendente de resposta — menos intrusivo.
3. **Configuração por board**: deixar o usuário escolher o comportamento nas configurações do kanban.

Verificar como o webhook/evento de nova mensagem pode disparar essa lógica.
