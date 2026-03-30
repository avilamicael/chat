---
created: 2026-03-30T15:05:11.530Z
title: Open conversation link in new tab from kanban card
area: ui
files: []
---

## Problem

Ao clicar no ícone/link que direciona para a conversa dentro do card do kanban, a navegação acontece na mesma aba. O comportamento esperado é abrir em uma nova aba para não perder o contexto do kanban.

## Solution

Adicionar `target="_blank"` e `rel="noopener noreferrer"` ao link/botão que abre a conversa no card kanban. Verificar se é um `<router-link>` (pode precisar de `window.open`) ou um `<a>` simples.
