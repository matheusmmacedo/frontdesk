/* global axios */
import ApiClient from './ApiClient';

class KlaosMessagePrefixAPI extends ApiClient {
  constructor() {
    super('klaos_message_prefix', { accountScoped: true });
  }
}

export default new KlaosMessagePrefixAPI();
