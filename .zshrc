# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

semLog() {
    "$@" >/dev/null 2>&1 &
    disown
}

espelharTela() {
    local opcao="${1:-}"
    [[ -z "$opcao" ]] && read "opcao?Opção [Trabalho(1) ou Resenha👀(2)]: "

    if [[ "$opcao" == "1" ]]; then
        hyprctl eval 'hl.config({
            general = { border_size = 0, gaps_in = 0, gaps_out = 0 },
            decoration = { rounding = 0 },
        })'
      #quickshell -c topbar ipc call bar toggle
    elif [[ "$opcao" != "2" ]]; then
        echo "Opção inválida." >&2
        return 1
    fi

    hyprctl eval 'hl.monitor({
        output = "HDMI-A-1",
        mode = "preferred",
        position = "0x0",
        scale = 1,
        mirror = "eDP-1",
    })'
}

unirTela() {
    hyprctl eval 'hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "1366x0", scale = 1 })'
}

tunel_ssh() {
    local modo porta_local porta_destino porta_ssh
    local usuario host_ssh chave resposta
    local tunel_pid tentativa codigo_saida
    local -a comando

    echo "💜 === Túnel SSH da Maia ==="
    echo "1) CachyOS → Termux"
    echo "2) Termux → CachyOS"
    read -r "modo?Escolha o destino [1/2]: "

    case "$modo" in
        1)
            porta_local=5000
            porta_destino=8023
            porta_ssh=8023
            usuario=u0_a514
            host_ssh=192.168.18.10
            chave="$HOME/.ssh/termux_maya"
            ;;
        2)
            porta_local=8024
            porta_destino=22
            porta_ssh=22
            usuario=biscoito
            host_ssh=192.168.18.28
            chave="$HOME/.ssh/id_ed25519"
            ;;
        *)
            echo "Opção inválida, desuwa~"
            return 1
            ;;
    esac

    if [[ ! -f "$chave" ]]; then
        echo "❌ Chave não encontrada: $chave"
        return 1
    fi

    if ss -H -ltn "sport = :$porta_local" 2>/dev/null |
        grep -q .; then
        echo "⚠️ A porta local $porta_local já está ocupada, desuwa."
        echo "Confira com: ss -ltnp 'sport = :$porta_local'"
        return 1
    fi

    comando=(
        ssh
        -N
        -p "$porta_ssh"
        -o ExitOnForwardFailure=yes
        -o ConnectTimeout=10
        -o BatchMode=yes
        -o StrictHostKeyChecking=yes
        -i "$chave"
        -L "127.0.0.1:${porta_local}:127.0.0.1:${porta_destino}"
        "${usuario}@${host_ssh}"
    )

    echo
    echo "🔌 Criando túnel para ${usuario}@${host_ssh}..."

    "${comando[@]}" &
    tunel_pid=$!

    tentativa=0
    while (( tentativa < 50 )); do
        if ! kill -0 "$tunel_pid" 2>/dev/null; then
            wait "$tunel_pid" 2>/dev/null
            echo "❌ Falha ao criar o túnel, desuwa."
            return 1
        fi

        if ss -H -ltn "sport = :$porta_local" 2>/dev/null |
            grep -q .; then
            break
        fi

        sleep 0.2
        (( tentativa++ ))
    done

    if (( tentativa >= 50 )); then
        echo "❌ O túnel não ficou disponível a tempo, desuwa."
        kill "$tunel_pid" 2>/dev/null
        wait "$tunel_pid" 2>/dev/null
        return 1
    fi

    echo "✨ Túnel ativo na porta $porta_local, desuwa!"
    read -r "resposta?Deseja acessar o dispositivo remoto? [s/N]: "

    codigo_saida=0

    if [[ "$resposta" == [sS] ]]; then
        echo "💻 Conectando ao dispositivo remoto..."

        ssh -p "$porta_local" \
            -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=yes \
            -i "$chave" \
            "${usuario}@127.0.0.1"

        codigo_saida=$?
    else
        echo "Acesso remoto cancelado, desuwa~"
    fi

    echo
    echo "🧹 Encerrando o túnel SSH..."

    kill "$tunel_pid" 2>/dev/null
    wait "$tunel_pid" 2>/dev/null

    echo "💜 Túnel encerrado, desuwa~"
    return "$codigo_saida"
}

sugerir_commit() {
    local mensagem="$*"

    if [ -z "$mensagem" ]; then
        echo "Hmph, cadê a mensagem do commit? Não vou adivinhar, baka."
        return 1
    fi

    local -a tipos=(
        "feat|Nova funcionalidade"
        "fix|Correção de bug"
        "docs|Mudança apenas na documentação"
        "style|Formatação, espaços, vírgulas (sem mudar lógica)"
        "refactor|Reescrita de código sem mudar comportamento"
        "perf|Melhoria de desempenho"
        "test|Adição ou correção de testes"
        "build|Mudanças no build ou nas dependências"
        "ci|Mudanças na integração contínua"
        "chore|Tarefas de manutenção"
        "revert|Reverte um commit anterior"
    )
    local total=${#tipos[@]}

    echo "Padrões de commit para: \"$mensagem\""
    echo

    local i=1 entrada tipo descricao
    for entrada in "${tipos[@]}"; do
        tipo="${entrada%%|*}"
        descricao="${entrada#*|}"
        printf "%2d) %-9s %s\n" "$i" "$tipo" "$descricao"
        i=$((i + 1))
    done
    echo

    local escolha
    printf "Escolha um número (1-%d): " "$total"
    read -r escolha

    if ! [[ "$escolha" =~ ^[0-9]+$ ]] || (( escolha < 1 || escolha > total )); then
        echo "Número inválido. Tenta de novo, vai."
        return 1
    fi

    # Percorre o array com contador: funciona igual em bash e zsh
    i=1
    for entrada in "${tipos[@]}"; do
        if (( i == escolha )); then
            tipo="${entrada%%|*}"
            break
        fi
        i=$((i + 1))
    done

    local -a cmd=(git commit -m "$tipo: $mensagem")

    echo
    echo "Comando gerado:"
    printf '  %q ' "${cmd[@]}"
    echo
    echo

    local resp
    printf "Quer executar agora? [s/N] "
    read -r resp

    case "$resp" in
        s|S|sim|SIM|Sim)
            "${cmd[@]}"
            ;;
        *)
            echo "Tá bom, não executei nada. Não é como se eu me importasse..."
            ;;
    esac
}
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
eval "$(luarocks path)"

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
