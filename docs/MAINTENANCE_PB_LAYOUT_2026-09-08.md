# Manutencao: layout de PB

## Problema

O mapa operacional colocava todos os locais de PB em uma unica linha. Como
cada cartao dividia o mesmo espaco horizontal, os textos eram reduzidos ate
ficarem praticamente ilegíveis. Alem disso, locais da categoria de area comum
eram apresentados com o texto fixo `Governança`, ocultando o nome real de cada
setor.

## Solucao

- O layout responsivo em grade foi aplicado somente ao bloco `PB`.
- Os demais andares e os chales conservam a distribuicao horizontal anterior.
- PB usa no maximo quatro colunas, espacamento uniforme e largura minima de
  150 px por cartao.
- Quando nao ha largura suficiente, os cartoes continuam em novas linhas.
- Todos os cartoes da grade mantêm a mesma largura.
- Areas comuns exibem o nome real do local cadastrado, como lobby, sala ou
  estacionamento, em vez de um texto generico.
- A nomenclatura visivel da categoria foi normalizada para `Área comum`.

## Validacao

- `dart format lib/features/maintenance/presentation/maintenance_page.dart lib/features/maintenance/domain/maintenance_models.dart`
- `flutter analyze lib/features/maintenance/presentation/maintenance_page.dart lib/features/maintenance/domain/maintenance_models.dart`: sem erros; permanecem nove avisos informativos preexistentes sobre APIs obsoletas.
- `flutter test`: 58 testes aprovados.

## Escopo

O ajuste nao altera contratos HTTP, persistencia ou regras das ordens. Apenas
o bloco PB e os textos visiveis de areas comuns foram modificados.
