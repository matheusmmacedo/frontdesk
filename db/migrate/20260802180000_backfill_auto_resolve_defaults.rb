# frozen_string_literal: true

# Backfill do auto-resolve por inatividade nas contas que existiam antes do
# default virar padrao da plataforma (custom/config/initializers/
# klaos_auto_resolve_default.rb cuida das contas NOVAS, via before_create).
#
# POR QUE MIGRATION E NAO NO BOOT
# A primeira versao fazia o backfill num `Thread.new` dentro do to_prepare —
# padrao copiado do audio_alerts_default.rb. Em dev isso falhou em TODO boot:
#
#   [AutoResolveDefault] backfill falhou: ActiveRecord::NoDatabaseError:
#     We could not find your database: railway
#
# A thread nasce fora do contexto de conexao do Rails e cai no database.yml
# cru, que monta host/base a partir de POSTGRES_* (defaults localhost /
# chatwoot_production); o app de verdade conecta pela DATABASE_URL. Nos
# requests nao aparece porque o pool ja esta estabelecido.
#
# Migration roda no preDeployCommand (`bundle exec rake db:migrate`), com o
# ambiente inteiro montado — o mesmo caminho pelo qual as outras migrations
# custom entraram sem problema.
#
# IDEMPOTENTE E RESPEITA O CLIENTE: o filtro e CHAVE AUSENTE, nao valor nulo.
# Quem desligar pela UI grava a chave com null e nao e religado por cima.

class BackfillAutoResolveDefaults < ActiveRecord::Migration[7.1]
  def up
    execute(<<~SQL.squish)
      UPDATE accounts
         SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
               'auto_resolve_after', 1440,
               'auto_resolve_ignore_waiting', true,
               'auto_resolve_label', 'auto-resolvida-inatividade'
             ),
             updated_at = NOW()
       WHERE NOT (COALESCE(settings, '{}'::jsonb) ? 'auto_resolve_after')
    SQL

    # Sem o Label a etiqueta nao aparece no filtro da UI: add_labels sozinho
    # cria so a tag do acts_as_taggable, nao o registro da conta.
    execute(<<~SQL.squish)
      INSERT INTO labels (title, description, color, show_on_sidebar, account_id, created_at, updated_at)
      SELECT 'auto-resolvida-inatividade',
             'Encerrada automaticamente por inatividade',
             '#6C757D',
             true,
             a.id,
             NOW(),
             NOW()
        FROM accounts a
       WHERE NOT EXISTS (
               SELECT 1 FROM labels l
                WHERE l.account_id = a.id
                  AND l.title = 'auto-resolvida-inatividade'
             )
    SQL
  end

  def down
    # Sem rollback de proposito: desligar o auto-resolve e decisao do cliente,
    # feita na UI. Reverter a migration apagaria essa escolha junto.
    raise ActiveRecord::IrreversibleMigration
  end
end
