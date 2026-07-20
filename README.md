# Gerenciador de Tarefas (mac)

App nativo em Swift (SwiftUI + AppKit) parecido com o Gerenciador de Tarefas do Windows 11.

## Funcionalidades

- Aba **Processos**: lista ao vivo (atualiza a cada 2s), ordenável por nome/PID/CPU/memória, busca, "Finalizar tarefa" (com confirmação) e "Forçar encerramento" no menu de contexto.
- Aba **Desempenho**: CPU (com gráfico), memória e disco em tempo real, lidos direto via APIs do sistema (sem shell out).
- Aba **Ajustes**: atalho global configurável (padrão `⌘⎋` — Cmd+Esc) e opção de abrir automaticamente no login.
- Ícone na barra de menu para abrir/fechar também por lá.

## Rodar

Precisa do Xcode Command Line Tools instalado (`xcode-select --install`).

```bash
./build_app.sh
open TaskManager.app
```

Isso compila em modo release, empacota em `TaskManager.app` e assina localmente (ad-hoc), para o macOS não bloquear.

Para desenvolvimento rápido sem empacotar:

```bash
swift run
```

(nesse modo o app roda, mas sem ícone customizado / metadados de bundle).

## Estrutura

- `Sources/TaskManager/AppDelegate.swift` — janela principal, ícone da barra de menu, liga o atalho global.
- `Sources/TaskManager/HotKeyManager.swift` — registro do atalho global via Carbon Event Manager (não precisa de permissão de Acessibilidade).
- `Sources/TaskManager/ProcessMonitor.swift` — snapshot de processos via `ps`.
- `Sources/TaskManager/SystemStats.swift` — CPU/memória/disco via Mach/Darwin.
- `Sources/TaskManager/Views/` — telas SwiftUI.
