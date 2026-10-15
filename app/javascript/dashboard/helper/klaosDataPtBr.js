/**
 * (15/10/2026) ADIAR: DATA ESCRITA DO JEITO BRASILEIRO.
 *
 * O campo de horário do Adiar (barra de comando) só entendia "2 horas",
 * "amanhã", "segunda-feira" e "26/10/2026". O que o atendente digita no dia a
 * dia voltava lista vazia, e sem sugestão não há o que escolher: o Gustavo leu
 * isso como "o botão adiar desabilitou" (conversa 1444, 15/10 09:30).
 *
 * Medido no parser em 15/10, com hoje = 15/10 09:30:
 *   "dia 26", "26/10", "26/10 08:00", "26 de outubro", "26 out",
 *   "segunda", "próxima segunda", "segunda dia 26"      -> nada
 *   "segunda 08:00"                                      -> AMANHÃ 08:00 (ignora "segunda")
 *   "03/11/2026"                                         -> nada (dia <= 12 é ambíguo)
 *
 * Este módulo traduz esses formatos para o inglês que o parser já entende
 * ("oct 26 2026 at 08:00", "monday at 08:00"). Mês por nome, nunca DD/MM, para
 * não cair na ambiguidade dia/mês. Devolve null quando o texto não é um desses
 * formatos: aí o fluxo de sempre segue.
 *
 * Ligado ao parser por patch (custom/vite/klaos-patches.js, localization.js).
 */

const MES_EN = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

const MESES = {
  jan: 0,
  janeiro: 0,
  fev: 1,
  fevereiro: 1,
  mar: 2,
  marco: 2,
  abr: 3,
  abril: 3,
  mai: 4,
  maio: 4,
  jun: 5,
  junho: 5,
  jul: 6,
  julho: 6,
  ago: 7,
  agosto: 7,
  set: 8,
  setembro: 8,
  out: 9,
  outubro: 9,
  nov: 10,
  novembro: 10,
  dez: 11,
  dezembro: 11,
};

const SEMANA = {
  dom: 'sunday',
  domingo: 'sunday',
  seg: 'monday',
  segunda: 'monday',
  ter: 'tuesday',
  terca: 'tuesday',
  qua: 'wednesday',
  quarta: 'wednesday',
  qui: 'thursday',
  quinta: 'thursday',
  sex: 'friday',
  sexta: 'friday',
  sab: 'saturday',
  sabado: 'saturday',
};

const limpar = texto =>
  String(texto ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

/** "08:00", "8h", "8h30", "as 14:30", "14h" no fim do texto. */
const separarHora = texto => {
  const m = texto.match(
    /(?:^|\s)(?:(?:as|a partir das|ate as)\s+)?(\d{1,2})(?::(\d{2})|h(\d{2})?)$/
  );
  if (!m) return { resto: texto, hora: null };
  const h = Number(m[1]);
  const mi = Number(m[2] ?? m[3] ?? 0);
  if (h > 23 || mi > 59) return { resto: texto, hora: null };
  return {
    resto: texto.slice(0, m.index).trim(),
    hora: `${String(h).padStart(2, '0')}:${String(mi).padStart(2, '0')}`,
  };
};

/**
 * Próxima data com esse dia (e mês, e ano), a partir de hoje. Sem mês: este
 * mês se o dia ainda não passou, senão o próximo mês que tem esse dia. Sem ano:
 * este ano se ainda não passou, senão o ano que vem.
 */
const proximaData = (dia, mes, ano, referencia) => {
  const hoje = new Date(
    referencia.getFullYear(),
    referencia.getMonth(),
    referencia.getDate()
  );
  if (!Number.isInteger(dia) || dia < 1 || dia > 31) return null;
  if (mes == null) {
    for (let k = 0; k < 13; k += 1) {
      const d = new Date(hoje.getFullYear(), hoje.getMonth() + k, dia);
      if (d.getDate() === dia && d >= hoje) return d;
    }
    return null;
  }
  if (ano != null) {
    const d = new Date(ano, mes, dia);
    return d.getMonth() === mes && d.getDate() === dia ? d : null;
  }
  for (let k = 0; k < 2; k += 1) {
    const d = new Date(hoje.getFullYear() + k, mes, dia);
    if (d.getMonth() === mes && d.getDate() === dia && d >= hoje) return d;
  }
  return null;
};

const anoCompleto = a => {
  if (a == null) return null;
  const n = Number(a);
  return n < 100 ? 2000 + n : n;
};

const emIngles = (data, hora) => {
  const base = `${MES_EN[data.getMonth()]} ${data.getDate()} ${data.getFullYear()}`;
  return hora ? `${base} at ${hora}` : base;
};

export const traduzirDataPtBr = (texto, referencia = new Date()) => {
  const { resto, hora } = separarHora(limpar(texto));
  const t = resto.replace(/^(?:(?:no|na|para|pra|ate)\s+)/, '');

  // "dia 26", "dia 26 de outubro", "dia 26 de outubro de 2026"
  let m = t.match(/^dia (\d{1,2})(?: de ([a-z]+))?(?: de (\d{4}))?$/);
  if (m) {
    const mes = m[2] != null ? MESES[m[2]] : null;
    if (m[2] != null && mes == null) return null;
    const d = proximaData(Number(m[1]), mes, anoCompleto(m[3]), referencia);
    return d ? emIngles(d, hora) : null;
  }

  // "26/10", "26/10/2026", "26-10", "26.10.26"
  m = t.match(/^(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?$/);
  if (m) {
    const mes = Number(m[2]) - 1;
    if (mes < 0 || mes > 11) return null;
    const d = proximaData(Number(m[1]), mes, anoCompleto(m[3]), referencia);
    return d ? emIngles(d, hora) : null;
  }

  // "26 de outubro", "26 out", "26 de outubro de 2026"
  m = t.match(/^(\d{1,2}) (?:de )?([a-z]+)\.?(?: (?:de )?(\d{4}))?$/);
  if (m && MESES[m[2]] != null) {
    const d = proximaData(
      Number(m[1]),
      MESES[m[2]],
      anoCompleto(m[3]),
      referencia
    );
    return d ? emIngles(d, hora) : null;
  }

  // "segunda", "segunda-feira", "proxima segunda", "segunda dia 26"
  m = t.match(
    /^(?:(?:proxima|proximo) )?([a-z]+)(?:-feira| feira)?(?: (?:dia )?(\d{1,2}))?$/
  );
  if (m && SEMANA[m[1]]) {
    if (m[2]) {
      const d = proximaData(Number(m[2]), null, null, referencia);
      return d ? emIngles(d, hora) : null;
    }
    return hora ? `${SEMANA[m[1]]} at ${hora}` : SEMANA[m[1]];
  }

  return null;
};

export default traduzirDataPtBr;
