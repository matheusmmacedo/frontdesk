# frozen_string_literal: true

# Backfill dos defaults de alerta sonoro nos usuarios que ja existiam.
#
# O custom/config/initializers/audio_alerts_default.rb declara duas camadas:
# before_create (usuario novo nasce com som ligado) e backfill no boot para os
# antigos. A primeira funciona; a SEGUNDA NUNCA RODOU. Em todo boot ela morre:
#
#   [AudioAlertsDefault] backfill falhou: ActiveRecord::NoDatabaseError:
#     We could not find your database: railway
#
# Mesma causa do backfill de auto-resolve (ver 20260802180000): o `Thread.new`
# dentro do to_prepare nasce fora do contexto de conexao do Rails e cai no
# database.yml cru — POSTGRES_* com defaults localhost/chatwoot_production —
# em vez da DATABASE_URL. O rescue engolia como log de erro e ninguem olhava.
#
# EFEITO DESTA MIGRATION: agente que nunca mexeu em Perfil -> Notificacoes de
# audio passa a OUVIR alerta. E a intencao original do initializer e o motivo
# dele existir ("novo atendente entra na conta, recebe conversa, nao escuta
# nada"). Quem ja configurou nao e tocado — o filtro e chave ausente.
#
# Combo identico ao do initializer, para as duas pontas nao divergirem.

class BackfillAudioAlertDefaults < ActiveRecord::Migration[7.1]
  def up
    execute(<<~SQL.squish)
      UPDATE users
         SET ui_settings = COALESCE(ui_settings, '{}'::jsonb) || jsonb_build_object(
               'enable_audio_alerts', 'all',
               'always_play_audio_alert', true,
               'alert_if_unread_assigned_conversation_exist', false,
               'notification_tone', 'ding'
             ),
             updated_at = NOW()
       WHERE NOT (COALESCE(ui_settings, '{}'::jsonb) ? 'enable_audio_alerts')
    SQL
  end

  def down
    # Sem rollback: preferencia de notificacao e do usuario, nao da migration.
    raise ActiveRecord::IrreversibleMigration
  end
end
