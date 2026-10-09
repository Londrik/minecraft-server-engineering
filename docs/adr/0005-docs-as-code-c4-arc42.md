# ADR 0005: Padrão Docs-as-Code com C4 Model e Arc42

## Status
Aceito

## Contexto
Documentações mantidas fora do repositório tornam-se rapidamente obsoletas e desvinculadas das versões ativas de plugins e configurações de produção.

## Decisão
Adotar o padrão Docs-as-Code dentro do diretório /docs, utilizando modelagem C4 com diagramas Mermaid declarativos e registros formais de decisão técnica via Architecture Decision Records (ADRs).

## Consequências
### Positivas
- Versionamento conjunto da documentação e do código-fonte via Git.
- Renderização nativa de diagramas na interface do repositório sem ferramentas proprietárias.

### Negativas
- Exige disciplina contínua da equipe para manter diagramas e ADRs sincronizados em revisões de código.
