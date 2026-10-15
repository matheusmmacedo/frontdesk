/**
 * (15/10/2026) Adiar com data escrita do jeito brasileiro.
 *
 * O Gustavo tentou adiar a conversa 1444 (Thiago) para "dia 26" e o campo não
 * deu nenhuma opção: "dia 26", "26/10", "26 de outubro", "segunda" voltavam
 * lista vazia, e "segunda 08:00" virava AMANHÃ 08:00. Hoje = qui 15/10 09:30.
 *
 * Os testes passam pelo fluxo real da barra de comando
 * (generateSnoozeSuggestions -> resolve), com o patch de klaos-patches.js.
 */
import { generateSnoozeSuggestions } from '../snoozeHelpers';
import { traduzirDataPtBr } from '../klaosDataPtBr';
import ptBr from '../../i18n/locale/pt_BR/snooze.json';

const agora = new Date('2026-10-15T09:30:00');
const opPt = { translations: ptBr.SNOOZE_PARSER, locale: 'pt_BR' };

const quando = texto => {
  const [s] = generateSnoozeSuggestions(texto, agora, opPt);
  if (!s) return null;
  const d = new Date(s.unixTime * 1000);
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm}/${d.getFullYear()} ${hh}:${mi}`;
};

describe('adiar: data brasileira', () => {
  it.each([
    ['dia 26', '26/10/2026 09:00'],
    ['Dia 26', '26/10/2026 09:00'],
    ['dia 26 às 8h', '26/10/2026 08:00'],
    ['26/10', '26/10/2026 09:00'],
    ['26/10 08:00', '26/10/2026 08:00'],
    ['26/10 às 14:30', '26/10/2026 14:30'],
    ['03/11', '03/11/2026 09:00'],
    ['03/11/2026', '03/11/2026 09:00'],
    ['26 de outubro', '26/10/2026 09:00'],
    ['26 out', '26/10/2026 09:00'],
    ['5 de janeiro', '05/01/2027 09:00'],
    ['segunda', '19/10/2026 09:00'],
    ['segunda-feira', '19/10/2026 09:00'],
    ['próxima segunda', '19/10/2026 09:00'],
    ['segunda 08:00', '19/10/2026 08:00'],
    ['segunda dia 26', '26/10/2026 09:00'],
    ['sexta 14h', '16/10/2026 14:00'],
  ])('"%s" vira %s', (texto, esperado) => {
    expect(quando(texto)).toBe(esperado);
  });

  it('dia que já passou neste mês vai para o mês que vem', () => {
    expect(quando('dia 10')).toBe('10/11/2026 09:00');
  });

  it('data que já passou neste ano vai para o ano que vem', () => {
    expect(quando('01/02')).toBe('01/02/2027 09:00');
  });
});

describe('vizinhos: o que já funcionava continua igual', () => {
  it.each([
    ['2 horas'],
    ['3 dias'],
    ['amanhã'],
    ['semana que vem'],
    ['30 minutos'],
  ])('"%s" segue pelo caminho de sempre', texto => {
    expect(traduzirDataPtBr(texto, agora)).toBeNull();
    expect(
      generateSnoozeSuggestions(texto, agora, opPt).length
    ).toBeGreaterThan(0);
  });

  it('"2 horas" continua duas horas à frente', () => {
    expect(quando('2 horas')).toBe('15/10/2026 11:30');
  });

  it('o que a barra grava (resolve, relógio real) é o mesmo instante da sugestão, em data absoluta', () => {
    const [s] = generateSnoozeSuggestions('26/10/2026 08:00', agora, opPt);
    expect(s.resolve()).toBe(s.unixTime);
  });

  it('em inglês o tradutor não entra', () => {
    const [s] = generateSnoozeSuggestions('dia 26', agora, { locale: 'en' });
    expect(s?.query ?? '').not.toContain('oct 26 2026');
  });

  it('data impossível não vira sugestão inventada', () => {
    expect(traduzirDataPtBr('31/02', agora)).toBeNull();
    expect(traduzirDataPtBr('26/13', agora)).toBeNull();
    expect(traduzirDataPtBr('dia 40', agora)).toBeNull();
  });
});
