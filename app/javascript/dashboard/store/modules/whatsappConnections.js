import WhatsappConnectionsAPI from '../../api/whatsappConnections';

const state = {
  records: [],
  phoneNumbers: {},
  templates: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isSyncing: false,
  },
};

const getters = {
  getConnections: $state => $state.records,
  getMetaConnections: $state =>
    $state.records.filter(c => c.provider === 'meta_cloud'),
  getEvolutionConnections: $state =>
    $state.records.filter(c => c.provider === 'evolution'),
  getConnectionById: $state => id =>
    $state.records.find(c => c.id === Number(id)),
  getPhoneNumbers: $state => connectionId =>
    $state.phoneNumbers[connectionId] || [],
  getTemplates: $state => connectionId =>
    $state.templates[connectionId] || [],
  getUIFlags: $state => $state.uiFlags,
};

const actions = {
  async fetchConnections({ commit }) {
    commit('setUIFlag', { isFetching: true });
    try {
      const { data } = await WhatsappConnectionsAPI.getConnections();
      commit('setConnections', data);
    } catch (error) {
      throw error;
    } finally {
      commit('setUIFlag', { isFetching: false });
    }
  },

  async createMetaConnection({ commit }, params) {
    commit('setUIFlag', { isCreating: true });
    try {
      const { data } = await WhatsappConnectionsAPI.createMetaConnection(
        params
      );
      commit('addConnection', data);
      return data;
    } catch (error) {
      throw error;
    } finally {
      commit('setUIFlag', { isCreating: false });
    }
  },

  async createEvolutionConnection({ commit }, params) {
    commit('setUIFlag', { isCreating: true });
    try {
      const { data } = await WhatsappConnectionsAPI.createEvolutionConnection(
        params
      );
      commit('addConnection', data);
      return data;
    } catch (error) {
      throw error;
    } finally {
      commit('setUIFlag', { isCreating: false });
    }
  },

  async deleteConnection({ commit }, connectionId) {
    await WhatsappConnectionsAPI.deleteConnection(connectionId);
    commit('removeConnection', connectionId);
  },

  async fetchPhoneNumbers({ commit }, connectionId) {
    const { data } = await WhatsappConnectionsAPI.getPhoneNumbers(connectionId);
    commit('setPhoneNumbers', { connectionId, phoneNumbers: data });
  },

  async linkPhoneNumber({ commit }, { connectionId, phoneNumberId, inboxName }) {
    const { data } = await WhatsappConnectionsAPI.linkPhoneNumber(
      connectionId,
      phoneNumberId,
      inboxName
    );
    commit('updatePhoneNumber', {
      connectionId,
      phoneNumber: data.phone_number,
    });
    return data;
  },

  async unlinkPhoneNumber({ commit }, { connectionId, phoneNumberId }) {
    const { data } = await WhatsappConnectionsAPI.unlinkPhoneNumber(
      connectionId,
      phoneNumberId
    );
    commit('updatePhoneNumber', { connectionId, phoneNumber: data });
    return data;
  },

  async syncNumbers({ commit }, connectionId) {
    commit('setUIFlag', { isSyncing: true });
    try {
      const { data } = await WhatsappConnectionsAPI.syncNumbers(connectionId);
      commit('updateConnection', data);
    } finally {
      commit('setUIFlag', { isSyncing: false });
    }
  },

  async fetchTemplates({ commit }, connectionId) {
    const { data } = await WhatsappConnectionsAPI.getTemplates(connectionId);
    commit('setTemplates', { connectionId, templates: data.templates || [] });
  },

  async createTemplate(_, { connectionId, params }) {
    return WhatsappConnectionsAPI.createTemplate(connectionId, params);
  },

  async updateTemplate({ dispatch }, { connectionId, templateId, params }) {
    await WhatsappConnectionsAPI.updateTemplate(connectionId, templateId, params);
    await dispatch('fetchTemplates', connectionId);
  },

  async deleteTemplate({ dispatch }, { connectionId, templateName }) {
    await WhatsappConnectionsAPI.deleteTemplate(connectionId, templateName);
    await dispatch('fetchTemplates', connectionId);
  },

  async syncTemplates({ commit }, connectionId) {
    commit('setUIFlag', { isSyncing: true });
    try {
      const { data } = await WhatsappConnectionsAPI.syncTemplates(connectionId);
      commit('setTemplates', {
        connectionId,
        templates: data.templates || [],
      });
    } finally {
      commit('setUIFlag', { isSyncing: false });
    }
  },

  // Evolution-specific actions
  async createInstance(_, { connectionId, displayName }) {
    return WhatsappConnectionsAPI.createInstance(connectionId, displayName);
  },

  async deleteInstance({ dispatch }, { connectionId, instanceId }) {
    await WhatsappConnectionsAPI.deleteInstance(connectionId, instanceId);
    await dispatch('fetchPhoneNumbers', connectionId);
  },

  async getQRCode(_, { connectionId, instanceId }) {
    const { data } = await WhatsappConnectionsAPI.getQRCode(
      connectionId,
      instanceId
    );
    return data;
  },

  async checkInstanceStatus(_, { connectionId, instanceId }) {
    const { data } = await WhatsappConnectionsAPI.getInstanceStatus(
      connectionId,
      instanceId
    );
    return data;
  },
};

const mutations = {
  setConnections($state, connections) {
    $state.records = connections;
  },
  addConnection($state, connection) {
    $state.records.push(connection);
  },
  updateConnection($state, connection) {
    const idx = $state.records.findIndex(c => c.id === connection.id);
    if (idx !== -1) {
      $state.records.splice(idx, 1, connection);
    }
  },
  removeConnection($state, connectionId) {
    $state.records = $state.records.filter(c => c.id !== connectionId);
  },
  setPhoneNumbers($state, { connectionId, phoneNumbers }) {
    $state.phoneNumbers = {
      ...$state.phoneNumbers,
      [connectionId]: phoneNumbers,
    };
  },
  updatePhoneNumber($state, { connectionId, phoneNumber }) {
    const numbers = $state.phoneNumbers[connectionId] || [];
    const idx = numbers.findIndex(n => n.id === phoneNumber.id);
    if (idx !== -1) {
      numbers.splice(idx, 1, phoneNumber);
    }
    $state.phoneNumbers = { ...$state.phoneNumbers, [connectionId]: numbers };
  },
  setTemplates($state, { connectionId, templates }) {
    $state.templates = { ...$state.templates, [connectionId]: templates };
  },
  setUIFlag($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
