# OpenBot para Umbrel

Loja comunitária do umbrelOS com o servidor do [OpenBot](https://openbot.run) (Nightly Labs).
O OpenBot roda agentes de IA no seu Umbrel. Você usa pelo app desktop, pelo iPhone ou por
openbot.run/app, com a mesma conta.

Este pacote usa a imagem oficial `ghcr.io/nightly-labs/openbot` com as opções do compose.yaml
oficial e acrescenta:

- Firewall aplicado no host a cada start: o container alcança só a internet. Rede local, outros
  apps do Umbrel e o próprio Umbrel ficam bloqueados.
- Backup de /data antes de cada troca de versão. Ficam os dois mais recentes em data/backups.
- Limites de 4 CPUs, 6 GB de RAM e 4096 processos.
- Página de status no ícone do Umbrel, atrás do login do Umbrel.
- Imagem fixada por versão e digest, atualizada por um robô (GitHub Actions).

Requisitos: umbrelOS 1.x ou 2.x, amd64 ou arm64, 4 GB de RAM livres e uma conta no OpenBot.
O provedor de IA (assinatura ou chave de API) é conectado pelo app do OpenBot.

## Instalar

1. No Umbrel, abra a App Store, menu de três pontos, Community App Stores.
2. Cole `https://github.com/woontersolucoes-wq/umbrel-apps-openbot` e clique em Add.
3. Abra a loja OpenBot e instale o app OpenBot.
4. Crie sua conta em https://openbot.run/app
5. No terminal do umbrelOS (Configurações, Configurações avançadas, Terminal), vincule o servidor:

       sudo docker exec -it openbot-server_server_1 openbot login --name umbrel

   Digite o e-mail da conta e o código que chegar. Depois, escolha o servidor no app do OpenBot.

## Atualizações

O workflow "Atualizar OpenBot" roda a cada 6 horas. Quando sai versão nova e os arquivos oficiais
`docker/compose.yaml` e `docker/seccomp.json` não mudaram, ele troca a imagem e a versão. O Umbrel
mostra a atualização na App Store, e você atualiza com um clique. O backup roda antes do OpenBot
iniciar na versão nova.

Quando esses arquivos mudam, o workflow abre uma issue com o diff e não atualiza até a revisão.
Depois da revisão, copie os arquivos novos para `upstream/compose.yaml` e
`openbot-server/seccomp.json`, ajuste o `docker-compose.yml` se preciso e rode o workflow manualmente.

Para usar em um fork, troque `woontersolucoes-wq/umbrel-apps-openbot` pelo seu repositório em
`openbot-server/umbrel-app.yml`.

## Rede

O OpenBot usa a rede `172.31.250.0/24` (bridge `br-openbot`). Se essa faixa já existir na sua
rede, troque a sub-rede em `openbot-server/docker-compose.yml`.

O firewall bloqueia 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 100.64.0.0/10 e
multicast. As regras ficam nas chains DOCKER-USER e INPUT com o comentário `openbot-server`.

## Restaurar um backup

No terminal do umbrelOS, com o app parado:

    cd /home/umbrel/umbrel/app-data/openbot-server/data
    mv openbot openbot-falhou
    mkdir openbot
    tar --numeric-owner -xzf backups/openbot-data-vX.Y.Z-AAAAMMDDTHHMMSSZ.tar.gz -C openbot

O backup é da versão anterior ao update. As migrações do OpenBot não voltam, então rode esse backup
com a imagem da mesma versão.
