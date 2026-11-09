# Loja Woonter OpenBot para Umbrel

Loja comunitária do umbrelOS com o app woonter-openbot.

Para adicionar no Umbrel: App Store, menu de três pontos, Community App Stores, cole
https://github.com/woontersolucoes-wq/umbrel-apps-openbot

## woonter-openbot

Container oficial do OpenBot (ghcr.io/nightly-labs/openbot) com as opções do compose.yaml
oficial, mais:

- Firewall aplicado no host a cada start: o container alcança só a internet, sem rede local e sem o host.
- Backup de /data antes de cada troca de versão, guardando os dois mais recentes em data/backups.
- Limites de 4 CPUs, 6 GB de RAM e 4096 processos.
- Página de status no ícone do Umbrel, atrás do login do Umbrel.

## Atualizações

O workflow Atualizar OpenBot roda a cada 6 horas. Quando sai versão nova e os arquivos
oficiais docker/compose.yaml e docker/seccomp.json não mudaram, ele troca a imagem (com digest)
e a versão. O Umbrel mostra a atualização na App Store.

Quando esses arquivos mudam, o workflow abre uma issue com o diff e não atualiza. Depois da
revisão, copie os arquivos novos para upstream/compose.yaml e woonter-openbot/seccomp.json,
ajuste o docker-compose.yml se preciso e rode o workflow manualmente.

## Restaurar um backup

No terminal do umbrelOS, com o app parado:

    cd /home/umbrel/umbrel/app-data/woonter-openbot/data
    mv openbot openbot-falhou
    mkdir openbot
    tar --numeric-owner -xzf backups/openbot-data-vX.Y.Z-AAAAMMDDTHHMMSSZ.tar.gz -C openbot

O backup é da versão anterior. Rode com a imagem dessa mesma versão.
