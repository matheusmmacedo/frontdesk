/**
 * (20/08/2026) O campo de adiar aceitava só inglês.
 *
 * O placeholder do modal está em português ("ex.: amanhã, 2 horas, próxima
 * sexta"), mas digitar "2 minutos" devolvia lista vazia e o atendente ficava
 * sem entender por quê. O parser SEMPRE teve suporte a outros idiomas — ele
 * traduz para inglês antes de interpretar — só que a tabela de tradução
 * (`SNOOZE_PARSER`) existia unicamente em `locale/en/snooze.json`. Faltava o
 * arquivo em pt_BR, não o mecanismo.
 *
 * Estes exemplos são o que um atendente brasileiro digita de verdade.
 */
import { generateDateSuggestions } from '../snoozeDateParser';
import ptBr from '../../i18n/locale/pt_BR/snooze.json';

const agora = new Date('2026-08-20T10:00:00');
const opcoesPt = { translations: ptBr.SNOOZE_PARSER, locale: 'pt-BR' };

const sugerir = texto => generateDateSuggestions(texto, agora, opcoesPt);

describe('adiar em português', () => {
  it.each([
    ['2 minutos'],
    ['30 minutos'],
    ['1 hora'],
    ['2 horas'],
    ['3 dias'],
    ['amanhã'],
    ['semana que vem'],
    ['mês que vem'],
  ])('entende "%s"', texto => {
    const sugestoes = sugerir(texto);
    expect(sugestoes.length).toBeGreaterThan(0);
    expect(sugestoes[0].date).toBeInstanceOf(Date);
  });

  it('"2 horas" cai duas horas à frente, não em outro dia', () => {
    const [primeira] = sugerir('2 horas');
    expect(primeira.date.getDate()).toBe(20);
    expect(primeira.date.getHours()).toBe(12);
  });

  it('"amanhã" cai no dia seguinte', () => {
    const [primeira] = sugerir('amanhã');
    expect(primeira.date.getDate()).toBe(21);
  });

  it('"30 minutos" respeita a unidade menor', () => {
    const [primeira] = sugerir('30 minutos');
    expect(primeira.date.getHours()).toBe(10);
    expect(primeira.date.getMinutes()).toBe(30);
  });

  // Blindagem: o inglês era o único que funcionava e não pode ter regredido —
  // a tradução roda como uma segunda tentativa, depois da tentativa em inglês.
  it('inglês continua funcionando com o locale em português', () => {
    const sugestoes = sugerir('2 hours');
    expect(sugestoes.length).toBeGreaterThan(0);
    expect(sugestoes[0].date.getHours()).toBe(12);
  });

  it('texto sem tempo nenhum continua devolvendo lista vazia', () => {
    expect(sugerir('obrigado pelo retorno')).toEqual([]);
    expect(sugerir('me liga depois')).toEqual([]);
  });

  /**
   * Preço conhecido e aceito de traduzir as unidades: "dia" e "hora" são
   * palavras corriqueiras em português, então "bom dia" casa a unidade e vira
   * a sugestão "1 dia". Num campo cuja única função é escolher um prazo isso é
   * inofensivo — a sugestão aparece e o atendente ignora. Está aqui para que a
   * próxima pessoa saiba que é esperado, e não um defeito novo.
   */
  it('"bom dia" sugere "1 dia" — efeito conhecido de "dia" ser unidade', () => {
    const sugestoes = sugerir('bom dia, tudo bem?');
    expect(sugestoes).toHaveLength(1);
    expect(sugestoes[0].label).toBe('1 dia');
  });
});
