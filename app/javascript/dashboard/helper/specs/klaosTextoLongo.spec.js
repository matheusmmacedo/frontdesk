/**
 * (30/10/2026) Texto longo no WhatsApp Cloud sai em várias mensagens.
 *
 * O Gustavo colou a resposta pronta de cancelamento (mais de 4096 caracteres)
 * na conversa da ELAINE e o Enviar ficou travado com "536 characters over".
 * O backend agora divide (klaos_whatsapp_texto_longo.rb); o composer só tem de
 * parar de bloquear e dizer em quantas mensagens o texto vai sair.
 *
 * Os números daqui têm de bater com
 * custom/app/services/klaos/whatsapp_texto_longo.rb.
 */
import fs from 'fs';
import path from 'path';
import klaosPatches from '../../../../../custom/vite/klaos-patches.js';
import {
  contarPartes,
  dividir,
  precisaDividir,
  tamanho,
  LIMITE_PARTE,
  RESERVA_PREFIXO,
} from '../klaosTextoLongo';

const paragrafo = n =>
  `👉 ${n} - VOCÊ CONCORDA COM A FRASE: o plano tem carência de 30 dias e a multa de cancelamento é calculada sobre as parcelas restantes do contrato.`;

// ~6000 unidades UTF-16, no formato das respostas de cancelamento (parágrafos
// curtos separados por linha em branco, emoji no começo).
const textoCancelamento = () => {
  const blocos = [];
  let n = 1;
  while (blocos.join('\n\n').length < 6000) {
    blocos.push(paragrafo(n));
    n += 1;
  }
  return blocos.join('\n\n');
};

describe('klaosTextoLongo — regra de divisão', () => {
  it('mensagem curta continua uma mensagem só, intacta', () => {
    const curta = 'Olá, tudo bem? Seu boleto já foi enviado.';
    expect(precisaDividir(curta)).toBe(false);
    expect(dividir(curta)).toEqual([curta]);
    expect(contarPartes(curta)).toBe(1);
  });

  it('até 3996 não divide (3996 + 100 de prefixo = 4096)', () => {
    expect(contarPartes('a'.repeat(3996))).toBe(1);
    expect(contarPartes('a'.repeat(3997))).toBe(2);
  });

  it('conta emoji como o contador do composer (UTF-16)', () => {
    expect(tamanho('👋')).toBe(2);
    expect(tamanho('👋 OLÁ')).toBe(6);
  });

  it('texto de cancelamento de ~6000 vira 2 partes, em ordem, sem perder nada', () => {
    const texto = textoCancelamento();
    const partes = dividir(texto);

    expect(partes.length).toBe(2);
    expect(tamanho(partes[0])).toBeLessThanOrEqual(
      LIMITE_PARTE - RESERVA_PREFIXO
    );
    partes.forEach(p => expect(tamanho(p)).toBeLessThanOrEqual(LIMITE_PARTE));
    // Quebra em parágrafo: nenhuma parte começa ou termina no meio de um.
    expect(partes[0].endsWith('contrato.')).toBe(true);
    expect(partes[1].startsWith('👉')).toBe(true);
    expect(partes.join('\n\n')).toBe(texto);
  });

  it('sem parágrafo, quebra na linha; sem linha, no espaço; nunca parte emoji', () => {
    const linhas = Array.from(
      { length: 80 },
      (_, i) => `linha ${i} ${'x'.repeat(60)}`
    ).join('\n');
    const porLinha = dividir(linhas);
    expect(porLinha.length).toBe(2);
    expect(porLinha.join('\n')).toBe(linhas);

    const palavras = Array.from({ length: 900 }, () => 'palavra').join(' ');
    const porEspaco = dividir(palavras);
    expect(porEspaco.join(' ')).toBe(palavras);

    const soEmoji = '😀'.repeat(2500);
    const partes = dividir(soEmoji);
    expect(partes.join('')).toBe(soEmoji);
    partes.forEach(p => expect(p.includes('�')).toBe(false));
    partes.forEach(p => expect(tamanho(p) % 2).toBe(0));
  });

  it('7000+ (a maior resposta, +CPI) vira 2 partes de no máximo 3900', () => {
    const texto = `${textoCancelamento()}\n\n${textoCancelamento().slice(0, 1100)}`;
    const partes = dividir(texto);
    expect(tamanho(texto)).toBeGreaterThan(7000);
    expect(partes.length).toBe(2);
    partes.forEach(p => expect(tamanho(p)).toBeLessThanOrEqual(LIMITE_PARTE));
  });
});

describe('klaos-patches — composer do WhatsApp', () => {
  const raiz = path.resolve(__dirname, '../../../../..');
  const aplicar = arquivo => {
    const plugin = klaosPatches();
    const id = path.join(raiz, arquivo).replace(/\\/g, '/');
    const codigo = fs.readFileSync(id, 'utf8');
    const resultado = plugin.transform(codigo, id);
    return resultado ? resultado.code : codigo;
  };

  it('ReplyBox para de bloquear só quando o texto vai ser dividido', () => {
    const code = aplicar(
      'app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue'
    );
    expect(code).toContain("from 'dashboard/helper/klaosTextoLongo'");
    expect(code).toContain('klaosPartesTextoLongo() {');
    // Nota privada e outros canais devolvem 1 parte: o bloqueio antigo vale.
    expect(code).toContain(
      'if (this.isPrivate || !this.isAWhatsAppCloudChannel) return 1;'
    );
    expect(code).toContain('this.klaosPartesTextoLongo < 2');
    expect(code).toContain(':klaos-partes="klaosPartesTextoLongo"');
  });

  it('ReplyTopPanel troca "characters over" por "Será enviada em N mensagens"', () => {
    const code = aplicar(
      'app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue'
    );
    expect(code).toContain('klaosPartes: {');
    // eslint-disable-next-line no-template-curly-in-string
    expect(code).toContain('Será enviada em ${this.klaosPartes} mensagens');
    expect(code).toContain(
      'v-if="isMessageLengthReachingThreshold || klaosPartes > 1"'
    );
    // Vizinho: com 1 parte o aviso antigo continua igual.
    expect(code).toContain('CHAR_LENGTH_WARNING.NEGATIVE');
  });
});
