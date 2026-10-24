<div align="center">

[![MetaGlassHack](.github/banner.svg)](#readme)

[![Último commit](https://img.shields.io/github/last-commit/gabrielxreis/metaglasshack?color=brightgreen&label=atualizado&style=for-the-badge)](https://github.com/gabrielxreis/metaglasshack/commits/main "Histórico")
[![macOS](https://img.shields.io/badge/macOS-14+-lightblue.svg?style=for-the-badge&logo=apple&logoColor=black)](#requisitos "Requisitos")
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138.svg?style=for-the-badge&logo=swift&logoColor=white)](#estrutura-do-repositorio "Estrutura")
[![Bluetooth](https://img.shields.io/badge/Bluetooth-BLE_+_Clássico-0082FC.svg?style=for-the-badge&logo=bluetooth&logoColor=white)](#oculos "Óculos")
[![Ray-Ban Meta](https://img.shields.io/badge/Ray--Ban_Meta-Gen_2-0866FF.svg?style=for-the-badge&logo=meta&logoColor=white)](#compatibilidade "Compatibilidade")
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB.svg?style=for-the-badge&logo=python&logoColor=white)](#requisitos "Requisitos")
[![Licença: MIT](https://img.shields.io/badge/-MIT-red.svg?style=for-the-badge)](LICENSE "Licença")

</div>

**MetaGlassHack** é um app nativo de Mac para quem usa os óculos **Ray-Ban Meta**. Ele pareia e conecta os óculos no Mac por Bluetooth, usa os óculos como **fone e microfone** do computador, mostra **bateria, firmware e o modo de conexão**, lê tudo o que os óculos expõem por **Bluetooth LE** e traz para o Mac as **fotos e vídeos** que os óculos gravaram, com miniaturas, seleção e um selo verde no que já foi copiado. Tudo com um visual escuro de vidro, sem conta, sem nuvem e sem servidor.

<div align="center">

<img src=".github/icon.png" width="128" alt="Ícone do MetaGlassHack">

| Óculos | Fotos e vídeos | Informações BLE |
|:---:|:---:|:---:|
| Pareia, conecta e vira fone e microfone do Mac | Miniaturas do que os óculos gravaram, com selo **NO MAC** | Cada serviço e campo que os óculos expõem, com log |

</div>

> **Projeto independente.** O MetaGlassHack não é da Meta nem da EssilorLuxottica e não tem nenhuma ligação com elas. "Meta" e "Ray-Ban" são marcas dos seus donos. O app não quebra criptografia e não mexe no firmware: ele usa o Bluetooth do macOS e lê o rolo da câmera do seu iPhone pelo cabo.

* [O QUE ELE FAZ](#o-que-ele-faz)
* [INSTALAÇÃO](#instalacao)
    * [Requisitos](#requisitos)
    * [Compilar e abrir](#compilar-e-abrir)
* [PRIMEIRO USO](#primeiro-uso)
    * [Parear os óculos no Mac](#parear-os-oculos-no-mac)
    * [Trazer as fotos e vídeos](#trazer-as-fotos-e-videos)
* [AS TELAS](#as-telas)
    * [Óculos](#oculos)
    * [Fotos e vídeos](#fotos-e-videos)
    * [Informações BLE](#informacoes-ble)
    * [Configurações](#configuracoes)
* [COMO FUNCIONA POR DENTRO](#como-funciona-por-dentro)
* [O QUE AINDA NÃO DÁ](#o-que-ainda-nao-da)
* [COMPATIBILIDADE](#compatibilidade)
* [ARMADILHAS CONHECIDAS](#armadilhas-conhecidas)
* [ESTRUTURA DO REPOSITÓRIO](#estrutura-do-repositorio)
* [PESQUISA E REFERÊNCIAS](#pesquisa-e-referencias)
* [LICENÇA](#licenca)


# O QUE ELE FAZ

- **Pareia os óculos no Mac.** Com a luz azul piscando, o app acha os óculos e pareia com um clique. Depois de pareados, as telas de pareamento somem e fica só um botão discreto para parear outro aparelho.
- **Fone e microfone do Mac.** Conecta e desconecta os óculos, escolhe a saída e a entrada de áudio do macOS e tem o atalho **"Só fone (som melhor)"**, que deixa o microfone no Mac para a música não cair para a qualidade de chamada.
- **Status ao vivo.** Bateria, firmware e modo (Fone + mic, Fone, Chamada) lidos direto do macOS, num cartão fixo na barra lateral.
- **Fotos e vídeos dos óculos no Mac.** Lê o rolo da câmera do iPhone **pelo cabo, em menos de 1 segundo**, separa só o que foi gravado pelos óculos (pelo metadado da câmera) e mostra as miniaturas **antes** de copiar. Você seleciona, passa para o Mac e o que já passou ganha o selo **NO MAC**. Os arquivos vão para `~/Pictures/Oculos Meta/AAAA-MM-DD/`.
- **Automático, se quiser.** Com o iPhone no cabo, o app confere de tempos em tempos e pode copiar sozinho o que chegar de novo.
- **Raio-X por Bluetooth LE.** Procura os óculos, conecta e lê cada serviço e campo (firmware, fabricante e os campos próprios da Meta), escuta notificações e salva um relatório em Markdown para pesquisa.


# INSTALAÇÃO

## Requisitos

| O que | Por quê |
|---|---|
| **macOS 14 (Sonoma) ou mais novo**, Apple Silicon | O app é SwiftUI nativo |
| **Xcode** ou as Command Line Tools (`xcode-select --install`) | Compila o app com `swiftc` |
| **Python 3.10+** | Roda o leitor do iPhone ([`pymobiledevice3`](https://github.com/doronz88/pymobiledevice3)), instalado sozinho no primeiro build |
| **Óculos Ray-Ban Meta** e o app **Meta AI** no iPhone | Os óculos mandam o que gravam para o Meta AI, que salva no rolo da câmera |
| **Cabo** iPhone ↔ Mac | Para trazer as fotos e vídeos sem iCloud |

## Compilar e abrir

```bash
git clone https://github.com/gabrielxreis/metaglasshack.git
```

```bash
cd metaglasshack && ./build.sh && open "build/Wayfarer Mac.app"
```

O `build.sh` cria o ambiente do leitor do iPhone (`tools/venv`) na primeira vez, compila o app, gera o ícone e assina. Se houver um certificado de desenvolvedor no Chaveiro, ele assina com ele (assim o macOS não esquece as permissões de Bluetooth e Fotos a cada build); se não houver, assina localmente.

Na primeira abertura o macOS pede **Bluetooth** (para achar e ler os óculos) e, se você usar a fonte "Fotos do Mac", **Fotos**.


# PRIMEIRO USO

## Parear os óculos no Mac

1. Coloque os óculos em **modo de pareamento**:
   - **No estojo aberto:** segure o botão de trás do estojo por 5 a 8 segundos, até a luz piscar azul.
   - **Fora do estojo:** hastes dobradas, segure o botão de captura (em cima da haste direita) por uns 12 segundos, até a luz de dentro piscar azul.
2. No app, aba **Óculos**, clique em **Procurar para parear** e depois em **Parear** nos óculos (aparecem como `RB Meta ...`).
3. Pronto: os óculos viram fone e microfone do Mac. Se não conectarem, eles provavelmente estão presos ao iPhone: desligue o Bluetooth do celular e clique em **Conectar**.

## Trazer as fotos e vídeos

1. No app **Meta AI** do iPhone, ligue **Importar automaticamente**: o que os óculos gravam vai para o rolo da câmera.
2. Ligue o iPhone no Mac **pelo cabo**, desbloqueie e toque em **Confiar** se ele perguntar.
3. Abra a aba **Fotos e vídeos**: em menos de 1 segundo aparecem as miniaturas do que veio dos óculos.
4. Clique para selecionar e use **Passar selecionados** (ou **Passar todos os novos**).


# AS TELAS

## Óculos

Cartão principal com o nome dos óculos, o selo **NO MAC** quando conectados, **bateria**, **firmware** e **modo**. Ao lado, a lista de aparelhos pareados com conectar e desconectar e o cartão **Áudio do Mac** com a saída e a entrada do sistema. A tela de pareamento só aparece quando não há óculos pareados (ou quando você pede para parear outro aparelho).

## Fotos e vídeos

Duas fontes:

| Fonte | Como funciona | Velocidade |
|---|---|---|
| **Do iPhone (cabo)** (padrão) | Lê o rolo da câmera do iPhone pelo cabo e confere o cabeçalho de cada arquivo | menos de 1 s |
| **Fotos do Mac** | Usa a biblioteca do app Fotos (iCloud) e confere o metadado | depende do iCloud |

Em cima, só uma **barra de progresso** com quantos arquivos dos óculos foram encontrados. Embaixo, a **galeria**: filtros Todos / Novos / No Mac, clique para selecionar, duplo clique abre o que já passou e o botão direito tem mais opções. Vídeos mostram a duração.

## Informações BLE

Procura aparelhos BLE (com o filtro **Só óculos**), conecta e lista cada serviço e campo com as permissões (ler, escrever, notificar). Os campos padrão são traduzidos (firmware, fabricante, bateria) e os demais aparecem em hexadecimal e texto. **Salvar relatório** gera um `.md` com tudo e o log.

## Configurações

A engrenagem no canto de cima da aba **Fotos e vídeos** abre:
- **Pasta no Mac** (padrão `~/Pictures/Oculos Meta`, com subpastas por dia).
- **Busca:** quantos dias olhar, passar sozinho quando chegar coisa nova, aceitar vídeo vertical 3:4 sem metadado, conferir tudo de novo.
- **Importar de uma pasta:** para arquivos que chegaram por AirDrop, cartão ou Downloads (copiar ou mover).


# COMO FUNCIONA POR DENTRO

```
 Óculos Ray-Ban Meta
   │  Bluetooth clássico (HFP/A2DP) ──────────────► Mac: fone e microfone (IOBluetooth + CoreAudio)
   │  Bluetooth LE (serviço 180A + FD5F da Meta) ──► Mac: informações e raio-X (CoreBluetooth)
   │
   │  Wi-Fi direto criptografado
   ▼
 App Meta AI (iPhone) ──► rolo da câmera ──cabo (AFC)──► Mac: miniaturas e cópia (pymobiledevice3)
```

- **Quem é dos óculos:** o arquivo dos óculos traz no metadado `Make = Meta AI` e `Model = Ray-Ban Meta Smart Glasses 2`. O leitor confere só o começo (e, nos vídeos, o fim) de cada arquivo, sem baixar o resto.
- **Bateria e firmware:** vêm do `system_profiler SPBluetoothDataType`, atualizados a cada 20 segundos.
- **Status de conexão:** conferido num objeto novo do `IOBluetoothDevice` e nos aparelhos de áudio ativos do CoreAudio (o objeto de `pairedDevices()` guarda um status velho).


# O QUE AINDA NÃO DÁ

- **Ler a memória dos óculos direto, sem o celular.** As fotos e vídeos saem dos óculos por um Wi-Fi direto **criptografado**, com uma chave que os servidores da Meta entregam só ao app Meta AI no pareamento. Pelo Bluetooth LE os óculos expõem apenas informações do aparelho e campos de controle. O caminho que funciona é o que o app usa: óculos → Meta AI → rolo da câmera → cabo → Mac.
- **Ler a pasta interna do app Meta AI.** O app não libera o compartilhamento de arquivos. Pelo backup local até dá, mas o iPhone manda o aparelho inteiro pelo cabo (dezenas de minutos) e a pasta guarda quase nada: o Meta AI apaga o original depois de salvar no rolo da câmera.
- **Câmera ao vivo no Mac.** A Meta só libera a câmera dos óculos para apps de celular, pelo [SDK oficial](https://github.com/facebook/meta-wearables-dat-ios). Funciona com um app de iPhone intermediário, mas exige o **Modo de Desenvolvedor** do iPhone e do Meta AI. Ficou fora desta versão.
- **Gerenciar os apps conectados aos óculos** (Spotify, WhatsApp, Instagram...): só pelo Meta AI, não há API pública.
- **Fotos antigas que estão só no iCloud.** Com "Otimizar Armazenamento" ligado no iPhone, os originais mais antigos não ficam no aparelho e não aparecem pelo cabo. Para esses, use a fonte **Fotos do Mac**.


# COMPATIBILIDADE

| Óculos | Bluetooth / áudio | Informações BLE | Fotos e vídeos |
|---|:---:|:---:|:---:|
| Ray-Ban Meta (Gen 2) | ✅ testado | ✅ testado | ✅ testado (via iPhone) |
| Ray-Ban Meta (Gen 1) | deve funcionar | deve funcionar | deve funcionar (via iPhone) |
| Oakley Meta | deve funcionar | deve funcionar | deve funcionar (via iPhone) |
| Ray-Ban Stories (2021) | deve funcionar | deve funcionar | o metadado é outro, pode não ser reconhecido |

Testado no macOS 27 com iPhone no iOS 27.


# ARMADILHAS CONHECIDAS

- **"Não deu (código ...)" ao conectar:** os óculos estão presos ao iPhone. Desligue o Bluetooth do celular por um minuto e conecte de novo.
- **Música com som de telefone:** com o microfone dos óculos ativo, o macOS usa o perfil de chamada. Use **Só fone (som melhor)**.
- **"Nenhum iPhone no cabo":** desbloqueie o iPhone e toque em **Confiar neste computador**.
- **O macOS pede permissão de novo depois de recompilar:** sem um certificado de desenvolvedor no Chaveiro, cada build é uma assinatura nova. O `build.sh` usa um certificado se houver.
- **Busca no Fotos lenta:** a fonte **Fotos do Mac** precisa baixar o original do iCloud para conferir o metadado. O app descarta na hora o que não pode ser dos óculos (Live Photos, prints, panorâmicas, o que não é 3:4) e dá no máximo 12 segundos por item. Prefira a fonte **Do iPhone (cabo)**.


# ESTRUTURA DO REPOSITÓRIO

```
metaglasshack/
├── Sources/
│   ├── App.swift            # interface (SwiftUI), design e as três telas
│   ├── BLEScanner.swift     # Bluetooth LE: busca, conexão, leitura de serviços e relatório
│   ├── Connections.swift    # Bluetooth clássico, pareamento, áudio (CoreAudio), bateria e firmware
│   └── MediaImporter.swift  # fotos e vídeos: iPhone pelo cabo, Fotos do Mac, pasta e galeria
├── tools/
│   ├── rolo_iphone.py       # leitor do rolo da câmera do iPhone pelo cabo (AFC)
│   ├── requirements.txt     # pymobiledevice3
│   └── make_icon.swift      # gera o ícone do app
├── build.sh                 # compila, gera o ícone e assina o .app em build/
└── .github/                 # banner e ícone deste README
```


# PESQUISA E REFERÊNCIAS

- [**facebook/meta-wearables-dat-ios**](https://github.com/facebook/meta-wearables-dat-ios): SDK oficial da Meta (câmera e áudio dos óculos em apps de iPhone).
- [**KonradIT/storiesclient**](https://github.com/KonradIT/storiesclient): cliente independente para os Ray-Ban Stories (2021), com o mapa do protocolo BLE + Wi-Fi direto.
- [**doronz88/pymobiledevice3**](https://github.com/doronz88/pymobiledevice3): acesso ao iPhone pelo cabo, usado para ler o rolo da câmera.


# LICENÇA

[MIT](LICENSE). Use, modifique e distribua à vontade, mantendo o aviso de licença.
