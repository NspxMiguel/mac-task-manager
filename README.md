<div align="center">

# Gerenciador de Tarefas

**O Task Manager do Windows 11, nativo pro macOS.**

Lista de processos ao vivo, gráficos de CPU/memória/disco e um atalho global configurável — padrão `⌘⇧⎋` (Cmd+Shift+Esc) — pra abrir de qualquer lugar, igual `Ctrl+Shift+Esc` no Windows.

[![Release](https://img.shields.io/github/v/release/spxmiguel/mac-task-manager?label=release&color=0a84ff)](https://github.com/spxmiguel/mac-task-manager/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black?logo=apple)](#requisitos)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-orange?logo=swift)](#estrutura)
[![Homebrew](https://img.shields.io/badge/homebrew-cask-fbb040?logo=homebrew)](#instalação)
[![License](https://img.shields.io/github/license/spxmiguel/mac-task-manager?color=lightgrey)](LICENSE)

</div>

---

## Instalação

A forma mais fácil, via [Homebrew](https://brew.sh):

```bash
brew tap spxmiguel/tap        # adiciona meu repositório pessoal de pacotes ao Homebrew
brew install --cask task-manager  # baixa o código-fonte e compila o app na sua máquina
```

Isso **compila o app na sua própria máquina** em vez de baixar um binário pronto:

- Detecta se você tem as Command Line Tools do Xcode (gratuitas, não precisa de licença/conta paga)
- Se não tiver, já dispara a instalação e espera terminar sozinho
- Assim que estão prontas, compila e instala o app em `/Applications` — sem passo manual

Build local também significa **sem aviso de Gatekeeper** ("desenvolvedor não identificado"), já que esse aviso só aparece em binários baixados prontos de fora.

> Primeira vez usando esta tap? O Homebrew pode pedir para confiar nela antes de instalar (é uma trava de segurança para taps de terceiros — como esta é minha, é seguro confiar):
> ```bash
> brew trust --cask spxmiguel/tap/task-manager
> ```

Abra pelo Spotlight ou direto em `/Applications/TaskManager.app`. Pronto — `⌘⇧⎋` já funciona de cara.

---

## O que tem

| | |
|---|---|
| **Processos** | Lista ao vivo (atualiza a cada 2s), ordenável por nome / PID / CPU / memória, busca por nome ou PID, `Finalizar tarefa` com confirmação, `Forçar encerramento` no menu de contexto. Uso de CPU acima de 50% aparece em vermelho. |
| **Desempenho** | CPU com gráfico em tempo real, memória e disco — lidos direto via APIs nativas do sistema (Mach/Darwin), sem shell out. |
| **Ajustes** | Atalho global gravável na hora (clique e pressione a combinação desejada), padrão `⌘⇧⎋`. Opção de abrir automaticamente no login. |
| **Barra de menu** | Ícone fixo: clique para abrir/fechar a janela, clique com o botão direito para `Mostrar/Ocultar` ou `Sair` do app. |

---

## Requisitos

- macOS 13 (Ventura) ou mais recente
- Apple Silicon ou Intel

---

## Build a partir do código-fonte

Precisa do Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/spxmiguel/mac-task-manager.git  # baixa o código-fonte
cd mac-task-manager                                           # entra na pasta do projeto
./build_app.sh                                                # compila e empacota em TaskManager.app (assinado localmente)
open TaskManager.app                                          # abre o app recém-compilado
```

O script `build_app.sh` compila em modo release, empacota em `TaskManager.app` e assina localmente (ad-hoc) para o Gatekeeper não bloquear.

Para iterar rápido sem empacotar (compila e já roda direto, sem gerar o `.app`):

```bash
swift run
```

---

## Estrutura

```
Sources/TaskManager/
├── AppDelegate.swift        # janela principal, ícone da barra de menu, liga o atalho global
├── HotKeyManager.swift      # atalho global via Carbon Event Manager (não pede permissão de Acessibilidade)
├── ProcessMonitor.swift     # snapshot de processos via `ps`
├── SystemStats.swift        # CPU / memória / disco via Mach/Darwin
├── SettingsStore.swift      # persistência do atalho escolhido
└── Views/                   # telas SwiftUI (Processos, Desempenho, Ajustes)
```

---

<div align="center">

Feito por [@spxmiguel](https://github.com/spxmiguel)

</div>
