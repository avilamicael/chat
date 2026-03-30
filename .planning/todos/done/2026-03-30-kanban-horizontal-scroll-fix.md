---
created: 2026-03-30T15:05:11.530Z
title: Fix kanban horizontal scroll outside columns
area: ui
files: []
---

## Problem

O scroll dentro das colunas do kanban funciona corretamente (vertical), mas o scroll fora das colunas (no container principal) precisa ser horizontal para permitir visualizar todas as colunas quando há mais colunas do que cabem na tela.

## Solution

Ajustar o CSS/Tailwind do container principal do kanban para ter `overflow-x: auto` (ou `overflow-x: scroll`) e garantir que as colunas não quebrem linha (`flex-nowrap` ou similar). O scroll interno das colunas deve continuar vertical.
