/* global axios */
import ApiClient from './ApiClient';

class WhatsappConnectionsAPI extends ApiClient {
  constructor() {
    super('whatsapp_connections', { accountScoped: true });
  }

  // --- Connections ---
  getConnections() {
    return axios.get(this.url);
  }

  getConnection(connectionId) {
    return axios.get(`${this.url}/${connectionId}`);
  }

  createMetaConnection(params) {
    return axios.post(this.url, { provider: 'meta_cloud', ...params });
  }

  createEvolutionConnection(params) {
    return axios.post(this.url, { provider: 'evolution', ...params });
  }

  updateConnection(connectionId, params) {
    return axios.patch(`${this.url}/${connectionId}`, params);
  }

  deleteConnection(connectionId) {
    return axios.delete(`${this.url}/${connectionId}`);
  }

  // --- Phone Numbers ---
  getPhoneNumbers(connectionId) {
    return axios.get(`${this.url}/${connectionId}/phone_numbers`);
  }

  linkPhoneNumber(connectionId, phoneNumberId) {
    return axios.post(
      `${this.url}/${connectionId}/phone_numbers/${phoneNumberId}/link`
    );
  }

  unlinkPhoneNumber(connectionId, phoneNumberId) {
    return axios.post(
      `${this.url}/${connectionId}/phone_numbers/${phoneNumberId}/unlink`
    );
  }

  syncNumbers(connectionId) {
    return axios.post(`${this.url}/${connectionId}/sync_numbers`);
  }

  // --- Templates (Meta only) ---
  getTemplates(connectionId) {
    return axios.get(`${this.url}/${connectionId}/templates`);
  }

  createTemplate(connectionId, params) {
    return axios.post(`${this.url}/${connectionId}/templates`, params);
  }

  updateTemplate(connectionId, templateId, params) {
    return axios.patch(
      `${this.url}/${connectionId}/templates/${templateId}`,
      params
    );
  }

  deleteTemplate(connectionId, templateName) {
    return axios.delete(
      `${this.url}/${connectionId}/templates/${templateName}`
    );
  }

  syncTemplates(connectionId) {
    return axios.post(`${this.url}/${connectionId}/sync_templates`);
  }

  // --- Evolution Instances ---
  createInstance(connectionId, displayName) {
    return axios.post(`${this.url}/${connectionId}/instances`, {
      display_name: displayName,
    });
  }

  deleteInstance(connectionId, instanceId) {
    return axios.delete(
      `${this.url}/${connectionId}/instances/${instanceId}`
    );
  }

  getQRCode(connectionId, instanceId) {
    return axios.get(
      `${this.url}/${connectionId}/instances/${instanceId}/qrcode`
    );
  }

  getInstanceStatus(connectionId, instanceId) {
    return axios.get(
      `${this.url}/${connectionId}/instances/${instanceId}/status`
    );
  }

  disconnectInstance(connectionId, instanceId) {
    return axios.post(
      `${this.url}/${connectionId}/instances/${instanceId}/disconnect`
    );
  }
}

export default new WhatsappConnectionsAPI();
