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
- Trava de segurança: o OpenBot só inicia depois que o firewall foi aplicado no boot atual.

Requisitos: umbrelOS 1.x ou 2.x, amd64 ou arm64, 4 GB de RAM livres e uma conta no OpenBot.
O provedor de IA (assinatura ou chave de API) é conectado pelo app do OpenBot.

Testado em umbrelOS 2.1 (x86_64). Em umbrelOS 1.x e arm64 o pacote segue o mesmo formato, mas
ainda não foi testado.

## Quando precisa de root

A instalação, as atualizações e a desinstalação são pela interface do Umbrel, sem root.
O root aparece em dois momentos, sempre com `sudo` e a senha do usuário umbrel:

- Login do OpenBot e comandos de diagnóstico (`sudo docker ...`), mostrados na página de status.
- Restaurar um backup.

Os hooks do app rodam com privilégio pelo próprio umbrelOS, como em qualquer app da loja oficial.
Só as regras de firewall usam esse privilégio. Pastas, backup e status rodam como usuário umbrel.

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

## Rede e segurança

O OpenBot fica numa rede própria (bridge `br-openbot`). O Docker escolhe a faixa livre
automaticamente, então não há conflito com a sua rede.

O firewall bloqueia 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 100.64.0.0/10 e
multicast. As regras ficam nas chains DOCKER-USER e INPUT com o comentário `openbot-server` e
são removidas ao desinstalar o app (hook `pre-uninstall`).

O umbrelOS ignora erros de hook. Por isso o hook grava `data/status/firewall-ok` com o boot_id
atual só depois de aplicar as regras, e o container `guard` confere esse arquivo. Se o arquivo
faltar ou for de outro boot, o OpenBot não inicia e a página de status mostra o motivo.

Os agentes do OpenBot têm acesso total dentro do container (arquivos, comandos, rede e navegador).
Rode só agentes em que você confia.

## Restaurar um backup

No terminal do umbrelOS, com o app parado:

    cd /home/umbrel/umbrel/app-data/openbot-server/data
    mv openbot openbot-falhou
    mkdir openbot
    tar --numeric-owner -xzf backups/openbot-data-vX.Y.Z-AAAAMMDDTHHMMSSZ.tar.gz -C openbot

O backup é da versão anterior ao update. As migrações do OpenBot não voltam, então rode esse backup
com a imagem da mesma versão.

## Licença

O OpenBot usa a licença PolyForm Noncommercial 1.0.0: uso pessoal e não comercial é livre, uso
comercial exige licença da Synthetify Labs (licenses@openbot.run). Veja o arquivo NOTICE.
