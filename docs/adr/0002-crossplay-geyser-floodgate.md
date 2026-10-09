# ADR 0002: Suporte a Crossplay via GeyserMC e Floodgate

## Status
Aceito

## Contexto
É necessário permitir acesso de clientes Bedrock (mobile, consoles, Windows) ao servidor Java sem exigir compra duplicada de licença Java e mantendo autenticação criptográfica segura.

## Decisão
Adotar GeyserMC para tradução de pacotes RakNet (UDP) em streams Java (TCP) em conjunto com o Floodgate para autenticação por chaves assimétricas e geração de UUIDs determinísticos derivados do XUID do Xbox Live.

## Consequências
### Positivas
- Integração de jogadores Java e Bedrock na mesma instância de mundo.
- UUIDs consistentes garantem integridade referencial em bancos relacionais.
- Autenticação legítima sem rebaixar a segurança do servidor para modo offline.

### Negativas
- Consumo de CPU adicional para tradução contínua de pacotes e entidades.
- Adaptação necessária de disparidades de mecânicas (combate 1.9+, offhand e redstone).
