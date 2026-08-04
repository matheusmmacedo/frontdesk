/* global axios */
import ApiClient from './ApiClient';

class KlaosMessagePrefixAPI extends ApiClient {
  constructor() {
    super('klaos_message_prefix', { accountScoped: true });
  }

  // Recurso SINGULAR: nao tem :id na URL. O `update` do ApiClient monta
  // `patch(${url}/${id}, data)` esperando (id, data) — chamado com um objeto
  // so, gerava `PATCH .../klaos_message_prefix/[object Object]` e body
  // `undefined`. Resultado: o botao Salvar da tela nunca gravou nada.
  update(data) {
    return axios.patch(this.url, data);
  }
}

export default new KlaosMessagePrefixAPI();
