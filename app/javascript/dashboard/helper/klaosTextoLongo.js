/**
 * KLaOS — texto longo no WhatsApp Cloud vira várias mensagens, na ordem.
 *
 * Pedido do Gustavo (26/10/2026): as respostas prontas de cancelamento passam
 * de 4096 caracteres (limite da Meta para texto) e o Enviar ficava travado com
 * "536 characters over". Quem divide e envia é o backend
 * (custom/config/initializers/klaos_whatsapp_texto_longo.rb); aqui fica o
 * espelho da regra só para o composer liberar o botão e avisar em quantas
 * mensagens o texto vai sair.
 *
 * A regra precisa ser a mesma de custom/app/services/klaos/whatsapp_texto_longo.rb:
 * tamanho em unidades UTF-16 (String#length), divide quando
 * tamanho + reserva do prefixo > 4096, blocos de no máximo 3900, a 1ª parte
 * guarda 100 para "**Atendente NOME:**\n", quebra em parágrafo, linha, espaço.
 */
export const LIMITE_META = 4096;
export const LIMITE_PARTE = 3900;
export const RESERVA_PREFIXO = 100;

const SEPARADORES = ['\n\n', '\n', ' '];
// Mesmo conjunto do \s e do rstrip do Ruby (só ASCII), para as contas baterem.
const ESPACO_FIM = /[ \t\r\n\f\v\0]+$/;
const ESPACO_INICIO = /^[ \t\r\n\f\v]+/;

const peso = c => (c.codePointAt(0) > 0xffff ? 2 : 1);

export const tamanho = texto => (texto || '').length;

export const precisaDividir = (texto, reserva = RESERVA_PREFIXO) =>
  tamanho(texto) + reserva > LIMITE_META;

// chars = array de code points (o índice do Ruby é por caractere).
function pontoDeCorte(chars, limite) {
  let cabe = 0;
  let usado = 0;
  while (cabe < chars.length && usado + peso(chars[cabe]) <= limite) {
    usado += peso(chars[cabe]);
    cabe += 1;
  }

  const minimo = Math.floor(cabe / 2);
  const achou = SEPARADORES.map(sep => {
    const seps = Array.from(sep);
    for (let i = cabe - seps.length; i >= minimo && i > 0; i -= 1) {
      if (seps.every((s, j) => chars[i + j] === s)) return [i, seps.length];
    }
    return null;
  }).find(Boolean);
  return achou || [cabe, 0];
}

export function dividir(texto, reserva = RESERVA_PREFIXO) {
  let resto = texto || '';
  if (!precisaDividir(resto, reserva)) return [resto];

  const partes = [];
  let limite = LIMITE_PARTE - reserva;
  while (tamanho(resto) > limite) {
    const chars = Array.from(resto);
    const [corte, pulo] = pontoDeCorte(chars, limite);
    const parte = chars.slice(0, corte).join('').replace(ESPACO_FIM, '');
    if (parte) partes.push(parte);
    resto = chars
      .slice(corte + pulo)
      .join('')
      .replace(ESPACO_INICIO, '');
    limite = LIMITE_PARTE;
  }
  if (resto) partes.push(resto);
  return partes;
}

export const contarPartes = texto =>
  precisaDividir(texto) ? dividir(texto).length : 1;
