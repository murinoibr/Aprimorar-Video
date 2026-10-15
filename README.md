# Aprimorar-Video (VanGogh)

Estúdio de vídeo e foto que roda inteiro no aparelho, com FFmpeg: sem nuvem,
sem modelo de IA pago, sem custo por uso.

## O que o app faz

- **Aprimorar** (vídeo e fotos em lote): upscale pelo lado menor (HD a 4K,
  vertical continua vertical), redução de ruído e banding, nitidez, estabilização,
  áudio limpo com volume padronizado e ajustes de cor. Prévia instantânea
  antes/depois: um quadro real processado pela mesma receita do export.
- **Looks de cinema**: Teal & Orange, Deserto, Neon Noir, Película 35mm, Noir
  Prata e Pastel, além das faixas 2.39:1. Tudo com filtros nativos do FFmpeg,
  sem LUT para baixar.
- **Melhores momentos**: uma passada de análise (só quadros-chave + energia do
  áudio) acha picos, cortes de cena e movimento; você escolhe 30 s a 2 min.
- **Cortar**: trechos com precisão de quadro, filmstrip real na timeline.
- **Exportação rápida**: cada trecho é renderizado com seek de entrada e unido
  por cópia, então o tempo depende do corte, não do tamanho da fonte. Se o
  encoder de hardware falhar, o app tenta de novo por software sozinho.
- **Biblioteca** persistente e "Salvar na galeria" em todo resultado.

## Testes

`flutter test` roda a lógica e a interface. `test/ffmpeg_native_test.dart`
executa os comandos gerados no FFmpeg instalado na máquina (é pulado se não
houver `ffmpeg` no PATH).

## Apoio opcional

Todos os recursos do app, incluindo exportação em 4K, são gratuitos e não mudam
com a assinatura. O plano é um apoio voluntário; RevenueCat valida compras e
restaura o entitlement `apoio`.

Configure a integração antes de testar compras:

1. Cadastre `aprimorar_video_pro_monthly` e `aprimorar_video_pro_yearly` como
	assinaturas no App Store Connect e no Google Play Console. Escolha o menor
	nível de preço disponível e configure período introdutório gratuito nos dois
	produtos para novos assinantes elegíveis.
2. Adicione os dois produtos no projeto RevenueCat e configure a conexão segura
	às lojas no painel. Não coloque credenciais privadas das lojas no app.
3. Crie o entitlement `apoio` e associe os produtos a ele.
4. Crie a offering atual `default`, com os pacotes mensal (`$rc_monthly`) e anual
	(`$rc_annual`). Os preços vêm da loja e não são fixados no código.
5. Passe as chaves públicas do SDK RevenueCat ao compilar:

```sh
flutter run \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_public_sdk_key \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_public_sdk_key
```

O checkout fica desabilitado para um pacote sem período introdutório de preço
zero. A elegibilidade do teste grátis é determinada pela loja; após o teste, o
preço e a renovação são mostrados antes da confirmação. Teste em TestFlight ou na
faixa de teste interno do Google Play com contas sandbox. Nenhum recurso do app
deve depender do entitlement.