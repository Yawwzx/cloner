#!/usr/bin/env bash

# Cores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITES_DIR="$DIR/Sites"
ZIPS_DIR="$DIR/Zips"

UA="Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
REJ_JS="js,mjs,*.js*"
REJ_MIDIA="png,jpg,jpeg,gif,svg,webp,avif,ico,bmp,woff,woff2,ttf,otf,eot,mp4,webm,mp3,ogg,wav"

sair_ctrlc() {
  echo -e "\n${R}Saindo...${N}"
  exit 0
}
trap sair_ctrlc INT

# ------------------------------------------
# BANNER (ASCII)
# ------------------------------------------
banner() {
  clear
  echo -e "${W}"
  cat << 'ASCII'
         ██╗   ██╗███████╗     ██████╗██╗      ██████╗ ███╗   ██╗███████╗██████╗
         ╚██╗ ██╔╝╚════██║    ██╔════╝██║     ██╔═══██╗████╗  ██║██╔════╝██╔══██╗
          ╚████╔╝     ██╔╝    ██║     ██║     ██║   ██║██╔██╗ ██║█████╗  ██████╔╝
           ╚██╔╝     ██╔╝     ██║     ██║     ██║   ██║██║╚██╗██║██╔══╝  ██╔══██╗
            ██║      ██║      ╚██████╗███████╗╚██████╔╝██║ ╚████║███████╗██║  ██║
            ╚═╝      ╚═╝       ╚═════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
ASCII
  echo -e "           ${W}Por: ${W}Yawwzx${N}"
  echo
}

pausar() {
  echo
  read -rp "Pressione ENTER para voltar ao painel..." _
}

item() {
  echo -e "${C}$1${W} - $2${N}"
}

instalar_pkg() {
  # $1 = comando a verificar | $2 = pacote do Termux
  if ! command -v "$1" >/dev/null 2>&1; then
    echo -e "${Y}[!] Instalando $2...${N}"
    pkg install "$2" -y || apt install "$2" -y
  fi
  command -v "$1" >/dev/null 2>&1
}

# Mostra os sites clonados numerados e guarda a escolha em SITE_ESCOLHIDO
escolher_site() {
  SITE_ESCOLHIDO=""
  local sites=() d n i

  for d in "$SITES_DIR"/*/; do
    [ -d "$d" ] && sites+=("$(basename "$d")")
  done

  if [ ${#sites[@]} -eq 0 ]; then
    echo -e "${R}[x] Nenhum site clonado ainda.${N}"
    return 1
  fi

  for i in "${!sites[@]}"; do
    item "$(printf '%02d' $((i + 1)))" "${sites[$i]}"
  done

  echo
  echo -ne "${W}Escolha o número do site (0 para voltar): ${G}"
  read -r n
  echo -ne "${N}"

  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  n=$((10#$n))
  { [ "$n" -ge 1 ] && [ "$n" -le ${#sites[@]} ]; } || return 1

  SITE_ESCOLHIDO="${sites[$((n - 1))]}"
  return 0
}

# Remove todas as tags <script> dos HTMLs (usado no modo Design)
remover_scripts() {
  local f
  find "$1" -type f -name "*.html" -print0 | while IFS= read -r -d '' f; do
    if awk -v RS='^$' '
      {
        s = $0; out = ""
        while ((i = match(s, /<[sS][cC][rR][iI][pP][tT]/)) > 0) {
          out = out substr(s, 1, i - 1)
          rest = substr(s, i)
          if ((j = match(rest, /<\/[sS][cC][rR][iI][pP][tT]>/)) > 0) s = substr(rest, j + RLENGTH)
          else s = ""
        }
        printf "%s%s", out, s
      }' "$f" > "$f.tmp" && [ -s "$f.tmp" ]; then
      mv "$f.tmp" "$f"
    else
      rm -f "$f.tmp"
    fi
  done
  # Apaga qualquer .js que tenha sobrado
  find "$1" -type f \( -name "*.js" -o -name "*.js?*" -o -name "*.mjs" \) -delete 2>/dev/null
}

# ------------------------------------------
# 01 / 02 / 03 - Clonar site
# ------------------------------------------
clonar_site() {
  local modo="$1" titulo desc url nome destino resp principal

  case "$modo" in
    full)   titulo="Clonar Site (Full)";   desc="HTML, CSS, JS, imagens e fontes" ;;
    design) titulo="Clonar Site (Design)"; desc="HTML, CSS, imagens e fontes (sem JavaScript)" ;;
    codigo) titulo="Clonar Site (Código)"; desc="HTML, CSS e JS (sem imagens e fontes)" ;;
  esac

  banner
  echo -e "${Y}[ $titulo ]${N}"
  echo -e "${W}Baixa: ${C}$desc${N}"
  echo
  echo -ne "${W}Digite a URL do site: ${G}"
  read -r url
  echo -ne "${N}"

  if [ -z "$url" ]; then
    echo -e "${R}[x] URL vazia.${N}"
    pausar
    return
  fi

  # Adiciona https:// se o usuário não colocou
  [[ "$url" =~ ^https?:// ]] || url="https://$url"

  # Nome da pasta = domínio do site
  nome=$(echo "$url" | sed -E 's|^https?://||; s|^www\.||; s|[/?#].*$||; s|:[0-9]+$||; s|[^A-Za-z0-9._-]|_|g')

  if [ -z "$nome" ]; then
    echo -e "${R}[x] URL inválida.${N}"
    pausar
    return
  fi

  destino="$SITES_DIR/$nome"

  # Se a pasta já existe, pergunta antes de substituir
  if [ -d "$destino" ] && [ -n "$(ls -A "$destino" 2>/dev/null)" ]; then
    echo -ne "${Y}[!] A pasta '$nome' já existe. Substituir? (s/N): ${G}"
    read -r resp
    echo -ne "${N}"
    if [[ ! "$resp" =~ ^[sSyY]$ ]]; then
      echo -e "${R}[x] Cancelado.${N}"
      pausar
      return
    fi
    rm -rf "$destino"
  fi

  mkdir -p "$destino"

  echo
  echo -e "${C}[*] Clonando: ${W}$url${N}"
  echo -e "${C}[*] Destino : ${W}$destino${N}"
  echo

  local args=(-nv -E -H -k -p -nH -e robots=off --tries=3 --timeout=20 --user-agent="$UA")
  case "$modo" in
    design) args+=(-R "$REJ_JS") ;;
    codigo) args+=(-R "$REJ_MIDIA") ;;
  esac

  wget "${args[@]}" -P "$destino" "$url"

  # Modo Design: tira as tags <script> dos HTMLs
  [ "$modo" = "design" ] && remover_scripts "$destino"

  # Garante que exista um index.html
  if [ ! -f "$destino/index.html" ]; then
    principal=$(find "$destino" -maxdepth 1 -type f -name "*.html" | head -n 1)
    [ -n "$principal" ] && cp "$principal" "$destino/index.html"
  fi

  local total html css js img
  total=$(find "$destino" -type f | wc -l)

  echo
  if [ "$total" -gt 0 ]; then
    html=$(find "$destino" -type f -name "*.html" | wc -l)
    css=$(find "$destino" -type f -name "*.css*" | wc -l)
    js=$(find "$destino" -type f -name "*.js*" | wc -l)
    img=$(find "$destino" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.webp" -o -iname "*.ico" \) | wc -l)
    echo -e "${G}[✔] Site clonado com sucesso!${N}"
    echo -e "${W}    Arquivos : ${G}$total${N}"
    echo -e "${W}    html: $html | css: $css | js: $js | imagens: $img${N}"
    echo -e "${W}    Pasta    : ${G}$destino${N}"
  else
    rmdir "$destino" 2>/dev/null
    echo -e "${R}[x] Não foi possível clonar o site. Verifique a URL e a internet.${N}"
  fi

  pausar
}

# ------------------------------------------
# 04 - Ver sites clonados
# ------------------------------------------
listar_sites() {
  local d i=0 n qtd tam
  banner
  echo -e "${Y}[ Sites clonados ]${N}"
  echo -e "${C}Pasta: ${W}$SITES_DIR${N}"
  echo

  for d in "$SITES_DIR"/*/; do
    [ -d "$d" ] || continue
    i=$((i + 1))
    n=$(basename "$d")
    qtd=$(find "$d" -type f | wc -l)
    tam=$(du -sh "$d" 2>/dev/null | cut -f1)
    echo -e "${Y}$(printf '%02d' "$i")${W} - $n ${C}($qtd arquivos | $tam)${N}"
  done

  [ "$i" -eq 0 ] && echo -e "${R}[x] Nenhum site clonado ainda.${N}"
  pausar
}

# ------------------------------------------
# 05 - Visualizar site clonado (servidor local)
# ------------------------------------------
servir_site() {
  local porta=8080
  banner
  echo -e "${Y}[ Visualizar site clonado ]${N}"
  echo

  escolher_site || { pausar; return; }

  instalar_pkg python3 python || { echo -e "${R}[x] Não foi possível instalar o Python.${N}"; pausar; return; }

  echo
  echo -e "${G}[✔] Servidor ativo (somente neste celular)!${N}"
  echo -e "${W}    Abra no navegador: ${C}http://127.0.0.1:$porta${N}"
  echo -e "${Y}    Pressione CTRL+C para parar o servidor.${N}"
  echo

  # CTRL+C para só o servidor, sem sair do painel
  trap ':' INT
  python3 -m http.server "$porta" --bind 127.0.0.1 --directory "$SITES_DIR/$SITE_ESCOLHIDO"
  trap sair_ctrlc INT

  echo
  echo -e "${R}[x] Servidor encerrado.${N}"
  pausar
}

# ------------------------------------------
# 06 - Compactar site em ZIP
# ------------------------------------------
compactar_site() {
  local saida
  banner
  echo -e "${Y}[ Compactar site em ZIP ]${N}"
  echo

  escolher_site || { pausar; return; }

  instalar_pkg zip zip || { echo -e "${R}[x] Não foi possível instalar o zip.${N}"; pausar; return; }

  mkdir -p "$ZIPS_DIR"
  saida="$ZIPS_DIR/$SITE_ESCOLHIDO.zip"
  rm -f "$saida"

  (cd "$SITES_DIR" && zip -rq "$saida" "$SITE_ESCOLHIDO")

  echo
  if [ -f "$saida" ]; then
    echo -e "${G}[✔] ZIP criado!${N}"
    echo -e "${W}    Arquivo: ${G}$saida${N}"
    echo -e "${C}    Dica: rode 'termux-setup-storage' uma vez e depois copie com:${N}"
    echo -e "${W}    cp \"$saida\" ~/storage/downloads/${N}"
  else
    echo -e "${R}[x] Falha ao criar o ZIP.${N}"
  fi

  pausar
}

# ------------------------------------------
# 07 - Apagar site clonado
# ------------------------------------------
apagar_site() {
  local resp
  banner
  echo -e "${Y}[ Apagar site clonado ]${N}"
  echo

  escolher_site || { pausar; return; }

  echo
  echo -ne "${Y}[!] Apagar '${SITE_ESCOLHIDO}' definitivamente? (s/N): ${G}"
  read -r resp
  echo -ne "${N}"

  if [[ "$resp" =~ ^[sSyY]$ ]] && [ -n "$SITE_ESCOLHIDO" ]; then
    rm -rf "$SITES_DIR/$SITE_ESCOLHIDO"
    echo -e "${G}[✔] Site apagado.${N}"
  else
    echo -e "${R}[x] Cancelado.${N}"
  fi

  pausar
}

# ------------------------------------------
# MENU
# ------------------------------------------
menu() {
  banner
  item "01" "Clonar Site (Full)"
  item "02" "Clonar Site (Design)"
  item "03" "Clonar Site (Código)"
  item "04" "Ver sites clonados"
  item "05" "Visualizar site clonado (local)"
  item "06" "Compactar site em ZIP"
  item "07" "Apagar site clonado"
  item "99" "Sair do painel"
  echo
  echo -ne "${W}Digite a opção: ${G}"
  read -r opcao
  echo -ne "${N}"
  [[ "$opcao" =~ ^[0-9]+$ ]] && opcao=$((10#$opcao))
}

# ------------------------------------------
# INÍCIO
# ------------------------------------------
instalar_pkg wget wget
mkdir -p "$SITES_DIR"

while true; do
  menu
  case "$opcao" in
    1)  clonar_site full ;;
    2)  clonar_site design ;;
    3)  clonar_site codigo ;;
    4)  listar_sites ;;
    5)  servir_site ;;
    6)  compactar_site ;;
    7)  apagar_site ;;
    99)
      echo
      echo -e "${G}Saindo do painel...${N}"
      exit 0
      ;;
    *)
      echo -e "\n${R}[x] Opção inválida!${N}"
      sleep 1
      ;;
  esac
done
