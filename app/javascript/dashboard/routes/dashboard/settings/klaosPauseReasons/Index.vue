<script>
// KLaOS — Settings de Motivos de Pausa (O.19 Pausas Tipadas).
//
// Admin-only. Tabela de motivos com ações add/edit/delete.
// Backend: /api/custom/v1/accounts/:id/pause_reasons (CRUD).
// Seeder cria 5 motivos default na primeira visita (Almoço, Banheiro,
// Reunião, Café, Outro).
//
// Modularidade: tudo em Klaos*, zero diff em upstream.
export default {
  data() {
    return {
      reasons: [],
      loading: true,
      error: null,
      saving: false,
      form: { name: '', icon: '🟡' },
      editingId: null,
    };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    },
    canSubmit() {
      return this.form.name.trim().length > 0 && !this.saving;
    },
  },
  mounted() {
    this.fetchReasons();
  },
  methods: {
    async fetchReasons() {
      this.loading = true;
      try {
        const { data } = await window.axios.get(
          `/api/custom/v1/accounts/${this.accountId}/pause_reasons`
        );
        this.reasons = data.reasons || [];
        this.error = null;
      } catch (e) {
        this.error = 'Erro ao carregar motivos.';
      } finally {
        this.loading = false;
      }
    },
    startEdit(reason) {
      this.editingId = reason.id;
      this.form = { name: reason.name, icon: reason.icon };
    },
    cancelEdit() {
      this.editingId = null;
      this.form = { name: '', icon: '🟡' };
    },
    async submit() {
      if (!this.canSubmit) return;
      this.saving = true;
      try {
        if (this.editingId) {
          await window.axios.patch(
            `/api/custom/v1/accounts/${this.accountId}/pause_reasons/${this.editingId}`,
            { reason: this.form }
          );
        } else {
          await window.axios.post(
            `/api/custom/v1/accounts/${this.accountId}/pause_reasons`,
            { reason: this.form }
          );
        }
        this.cancelEdit();
        this.fetchReasons();
      } catch (e) {
        const msg = e.response?.data?.errors?.join(', ') || 'Erro ao salvar.';
        this.error = msg;
      } finally {
        this.saving = false;
      }
    },
    async remove(reason) {
      if (!confirm(`Remover motivo "${reason.name}"?`)) return;
      try {
        await window.axios.delete(
          `/api/custom/v1/accounts/${this.accountId}/pause_reasons/${reason.id}`
        );
        this.fetchReasons();
      } catch (e) {
        this.error = 'Erro ao remover.';
      }
    },
  },
};
</script>

<template>
  <div class="klaos-pr-settings">
    <header class="klaos-pr-settings__header">
      <h1>Motivos de Pausa</h1>
      <p>
        Define os motivos que o agente pode escolher ao entrar em pausa
        (almoço, banheiro, reunião, ...). Aparece no Painel de Agentes
        ao lado do status atual.
      </p>
    </header>

    <form class="klaos-pr-settings__form" @submit.prevent="submit">
      <input
        v-model="form.icon"
        type="text"
        maxlength="4"
        placeholder="🟡"
        class="klaos-pr-settings__icon"
        :disabled="saving"
      />
      <input
        v-model="form.name"
        type="text"
        maxlength="50"
        placeholder="Nome do motivo (ex.: Almoço)"
        class="klaos-pr-settings__name"
        :disabled="saving"
      />
      <button
        type="submit"
        :disabled="!canSubmit"
        class="klaos-pr-settings__submit"
      >
        {{ editingId ? 'Salvar' : 'Adicionar' }}
      </button>
      <button
        v-if="editingId"
        type="button"
        class="klaos-pr-settings__cancel"
        @click="cancelEdit"
      >
        Cancelar
      </button>
    </form>

    <div v-if="error" class="klaos-pr-settings__err">{{ error }}</div>
    <div v-if="loading" class="klaos-pr-settings__loading">Carregando…</div>

    <table v-else class="klaos-pr-settings__table">
      <thead>
        <tr>
          <th>Ícone</th>
          <th>Nome</th>
          <th>Ordem</th>
          <th>Ações</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in reasons" :key="r.id">
          <td class="klaos-pr-settings__icon-cell">{{ r.icon }}</td>
          <td>{{ r.name }}</td>
          <td>{{ r.sort_order }}</td>
          <td class="klaos-pr-settings__actions">
            <button type="button" class="klaos-pr-settings__edit" @click="startEdit(r)">
              Editar
            </button>
            <button type="button" class="klaos-pr-settings__remove" @click="remove(r)">
              Remover
            </button>
          </td>
        </tr>
        <tr v-if="!reasons.length">
          <td colspan="4" class="klaos-pr-settings__empty">
            Nenhum motivo cadastrado.
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.klaos-pr-settings {
  padding: 24px;
  max-width: 800px;
}
.klaos-pr-settings__header h1 {
  font-size: 20px;
  font-weight: 700;
  margin: 0 0 4px;
}
.klaos-pr-settings__header p {
  font-size: 13px;
  color: #6b7280;
  margin: 0 0 20px;
}
.klaos-pr-settings__form {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.klaos-pr-settings__icon,
.klaos-pr-settings__name {
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 14px;
}
.klaos-pr-settings__icon {
  width: 60px;
  text-align: center;
  font-size: 20px;
}
.klaos-pr-settings__name {
  flex: 1;
  min-width: 200px;
}
.klaos-pr-settings__submit,
.klaos-pr-settings__cancel,
.klaos-pr-settings__edit,
.klaos-pr-settings__remove {
  padding: 8px 16px;
  border-radius: 6px;
  border: 1px solid transparent;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
.klaos-pr-settings__submit {
  background: #2563eb;
  color: white;
}
.klaos-pr-settings__submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.klaos-pr-settings__cancel {
  background: #f3f4f6;
  color: #374151;
  border-color: #d1d5db;
}
.klaos-pr-settings__edit {
  background: #fef3c7;
  color: #78350f;
  border-color: #fcd34d;
}
.klaos-pr-settings__remove {
  background: #fee2e2;
  color: #991b1b;
  border-color: #fca5a5;
}
.klaos-pr-settings__err {
  background: #fee2e2;
  color: #b91c1c;
  padding: 8px 12px;
  border-radius: 6px;
  margin-bottom: 12px;
  font-size: 13px;
}
.klaos-pr-settings__loading {
  padding: 24px;
  text-align: center;
  color: #6b7280;
}
.klaos-pr-settings__table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}
.klaos-pr-settings__table th {
  text-align: left;
  padding: 10px 14px;
  background: #f9fafb;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  color: #6b7280;
  border-bottom: 1px solid #e5e7eb;
}
.klaos-pr-settings__table td {
  padding: 10px 14px;
  border-bottom: 1px solid #f3f4f6;
  font-size: 14px;
}
.klaos-pr-settings__icon-cell {
  font-size: 20px;
  text-align: center;
}
.klaos-pr-settings__actions {
  display: flex;
  gap: 6px;
}
.klaos-pr-settings__empty {
  text-align: center;
  padding: 32px;
  color: #6b7280;
}
</style>
